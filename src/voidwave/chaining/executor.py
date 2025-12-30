"""Chain executor for running tool pipelines."""

import asyncio
from collections import defaultdict
from datetime import datetime
from typing import Any

from voidwave.chaining.models import (
    ChainDefinition,
    ChainResult,
    ChainStep,
    Condition,
    DataBinding,
    OnErrorBehavior,
    StepResult,
    StepStatus,
)
from voidwave.chaining.paths import resolve_path
from voidwave.chaining.transforms import get_transform
from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.orchestration.workflow import WorkflowContext
from voidwave.plugins.registry import plugin_registry

logger = get_logger(__name__)


class ChainExecutionError(Exception):
    """Raised when chain execution fails due to configuration errors."""

    pass


class ChainExecutor:
    """Executes tool chains with dependency tracking and data binding."""

    def __init__(
        self,
        context: WorkflowContext | None = None,
        session: Any = None,
    ) -> None:
        """Initialize chain executor.

        Args:
            context: Optional workflow context for result storage
            session: Optional session for persistence
        """
        self.context = context
        self.session = session
        self._step_results: dict[str, StepResult] = {}
        self._running_tasks: dict[str, asyncio.Task] = {}
        self._cancelled = False
        self._current_chain_id: str | None = None

    async def execute(self, chain: ChainDefinition, target: str | None = None) -> ChainResult:
        """Execute a complete chain.

        Args:
            chain: The chain definition to execute
            target: Override target for the chain

        Returns:
            ChainResult with all step results

        Raises:
            ChainExecutionError: If chain has cycles or unreachable steps
        """
        result = ChainResult(
            chain_id=chain.id,
            success=True,
            started_at=datetime.now(),
        )
        self._current_chain_id = chain.id

        logger.info(f"Starting chain: {chain.name} ({chain.id})")

        # Emit chain start event
        event_bus.emit(
            Events.CHAIN_STARTED,
            {
                "chain_id": chain.id,
                "chain_name": chain.name,
                "step_count": len(chain.steps),
            },
        )

        # Store target in context if provided
        if target and self.context:
            self.context.target = target

        # Build execution order with cycle detection
        try:
            execution_order = self._build_execution_order(chain.steps)
        except ChainExecutionError as e:
            result.success = False
            result.errors.append(str(e))
            result.ended_at = datetime.now()
            self._emit_chain_failed(chain.id, str(e))
            return result

        # Execute steps in order
        for step_group in execution_order:
            if self._cancelled:
                result.success = False
                result.errors.append("Chain cancelled")
                self._emit_chain_cancelled(chain.id)
                break

            # Execute group (parallel if multiple)
            group_results = await self._execute_group(step_group, chain, target)

            # Process results
            for step_id, step_result in group_results.items():
                self._step_results[step_id] = step_result
                result.steps[step_id] = step_result

                if step_result.status == StepStatus.FAILED:
                    step = self._get_step(chain, step_id)
                    if step:
                        # Handle different error behaviors
                        if step.on_error == OnErrorBehavior.STOP:
                            result.success = False
                            result.errors.extend(step_result.errors)
                            result.ended_at = datetime.now()
                            result.total_duration = (
                                result.ended_at - result.started_at
                            ).total_seconds()
                            self._emit_chain_failed(chain.id, step_result.errors)
                            return result
                        elif step.on_error == OnErrorBehavior.SKIP:
                            # Mark as skipped instead of failed, continue
                            step_result.status = StepStatus.SKIPPED
                            logger.info(f"Step {step_id} failed but SKIP mode - continuing")
                        # RETRY is handled in _execute_step, FALLBACK too

        # Aggregate final output
        result.final_output = self._aggregate_outputs(chain)
        result.ended_at = datetime.now()
        result.total_duration = (result.ended_at - result.started_at).total_seconds()

        # Store in context
        if self.context:
            self.context.results[chain.id] = result.final_output

        # Emit chain completion event
        event_bus.emit(
            Events.CHAIN_COMPLETED,
            {
                "chain_id": chain.id,
                "success": result.success,
                "duration": result.total_duration,
                "steps_completed": sum(
                    1 for s in result.steps.values() if s.status == StepStatus.COMPLETED
                ),
                "steps_failed": sum(
                    1 for s in result.steps.values() if s.status == StepStatus.FAILED
                ),
                "steps_skipped": sum(
                    1 for s in result.steps.values() if s.status == StepStatus.SKIPPED
                ),
            },
        )

        logger.info(
            f"Chain completed: {chain.name} - "
            f"{'success' if result.success else 'failed'} "
            f"({result.total_duration:.2f}s)"
        )

        self._current_chain_id = None
        return result

    def _emit_chain_failed(self, chain_id: str, errors: list[str] | str) -> None:
        """Emit chain failed event."""
        event_bus.emit(
            Events.CHAIN_FAILED,
            {
                "chain_id": chain_id,
                "errors": errors if isinstance(errors, list) else [errors],
            },
        )

    def _emit_chain_cancelled(self, chain_id: str) -> None:
        """Emit chain cancelled event."""
        event_bus.emit(
            Events.CHAIN_CANCELLED,
            {"chain_id": chain_id},
        )

    async def _execute_group(
        self,
        steps: list[ChainStep],
        chain: ChainDefinition,
        target: str | None,
    ) -> dict[str, StepResult]:
        """Execute a group of steps (parallel if multiple)."""
        if len(steps) == 1:
            result = await self._execute_step(steps[0], chain, target)
            return {steps[0].id: result}

        # Parallel execution
        tasks = {}
        for step in steps:
            task = asyncio.create_task(self._execute_step(step, chain, target))
            tasks[step.id] = task
            self._running_tasks[step.id] = task

        results = {}
        for step_id, task in tasks.items():
            try:
                results[step_id] = await task
            except Exception as e:
                step = self._get_step(chain, step_id)
                results[step_id] = StepResult(
                    step_id=step_id,
                    tool=step.tool if step else "unknown",
                    status=StepStatus.FAILED,
                    errors=[str(e)],
                )
                # Emit step failed event
                event_bus.emit(
                    Events.CHAIN_STEP_FAILED,
                    {
                        "chain_id": chain.id,
                        "step_id": step_id,
                        "error": str(e),
                    },
                )
            finally:
                self._running_tasks.pop(step_id, None)

        return results

    async def _execute_step(
        self,
        step: ChainStep,
        chain: ChainDefinition,
        chain_target: str | None,
    ) -> StepResult:
        """Execute a single step."""
        result = StepResult(
            step_id=step.id,
            tool=step.tool,
            status=StepStatus.RUNNING,
            started_at=datetime.now(),
        )

        logger.debug(f"Executing step: {step.id} ({step.tool})")

        # Emit step started event
        event_bus.emit(
            Events.CHAIN_STEP_STARTED,
            {
                "chain_id": chain.id,
                "step_id": step.id,
                "tool": step.tool,
                "description": step.description,
            },
        )

        # Check condition
        if step.condition and not self._evaluate_condition(step.condition):
            result.status = StepStatus.SKIPPED
            result.ended_at = datetime.now()
            logger.debug(f"Step skipped (condition not met): {step.id}")
            event_bus.emit(
                Events.CHAIN_STEP_SKIPPED,
                {
                    "chain_id": chain.id,
                    "step_id": step.id,
                    "reason": "condition_not_met",
                },
            )
            return result

        # Resolve target
        target = self._resolve_target(step, chain_target)
        if not target:
            result.status = StepStatus.FAILED
            result.errors.append("Could not resolve target")
            result.ended_at = datetime.now()
            self._emit_step_failed(chain.id, step.id, result.errors)
            return result

        # Resolve options with bindings
        try:
            options = self._resolve_options(step)
        except ValueError as e:
            result.status = StepStatus.FAILED
            result.errors.append(str(e))
            result.ended_at = datetime.now()
            self._emit_step_failed(chain.id, step.id, result.errors)
            return result

        # Get tool instance
        try:
            tool = await plugin_registry.get_instance(step.tool)
        except KeyError:
            result.status = StepStatus.FAILED
            result.errors.append(f"Tool not found: {step.tool}")
            result.ended_at = datetime.now()
            self._emit_step_failed(chain.id, step.id, result.errors)
            return result

        # Determine retry count based on OnErrorBehavior
        # RETRY mode enables retries, other modes use retry_count only if > 0
        max_attempts = step.retry_count + 1 if step.on_error == OnErrorBehavior.RETRY else max(1, step.retry_count + 1)

        # Execute with retry logic
        for attempt in range(max_attempts):
            try:
                # Set timeout in options
                if step.timeout:
                    options["timeout"] = step.timeout

                plugin_result = await tool.execute(target, options)

                if plugin_result.success:
                    result.status = StepStatus.COMPLETED
                    result.data = plugin_result.data
                    result.ended_at = datetime.now()
                    result.duration = (
                        result.ended_at - result.started_at
                    ).total_seconds()
                    result.retries = attempt

                    logger.debug(
                        f"Step completed: {step.id} ({result.duration:.2f}s)"
                    )

                    # Emit step completed event
                    event_bus.emit(
                        Events.CHAIN_STEP_COMPLETED,
                        {
                            "chain_id": chain.id,
                            "step_id": step.id,
                            "tool": step.tool,
                            "duration": result.duration,
                            "retries": attempt,
                        },
                    )
                    return result

                result.errors.extend(plugin_result.errors)

            except asyncio.TimeoutError:
                result.errors.append(f"Timeout after {step.timeout}s")
            except asyncio.CancelledError:
                result.status = StepStatus.FAILED
                result.errors.append("Cancelled")
                result.ended_at = datetime.now()
                self._emit_step_failed(chain.id, step.id, result.errors)
                return result
            except Exception as e:
                result.errors.append(str(e))
                logger.warning(f"Step {step.id} attempt {attempt + 1} failed: {e}")

            result.retries = attempt

            # Retry delay with exponential backoff
            if attempt < max_attempts - 1:
                delay = step.retry_delay * (2 ** attempt)
                logger.debug(f"Retrying step {step.id} in {delay:.1f}s (attempt {attempt + 2}/{max_attempts})")
                await asyncio.sleep(delay)

        # Try fallback if available and on_error is FALLBACK
        if step.fallback_tool and step.on_error == OnErrorBehavior.FALLBACK:
            fallback_result = await self._try_fallback(step, chain.id, target, options)
            if fallback_result.status == StepStatus.COMPLETED:
                return fallback_result

        result.status = StepStatus.FAILED
        result.ended_at = datetime.now()
        result.duration = (result.ended_at - result.started_at).total_seconds()

        self._emit_step_failed(chain.id, step.id, result.errors)
        return result

    def _emit_step_failed(self, chain_id: str, step_id: str, errors: list[str]) -> None:
        """Emit step failed event."""
        event_bus.emit(
            Events.CHAIN_STEP_FAILED,
            {
                "chain_id": chain_id,
                "step_id": step_id,
                "errors": errors,
            },
        )

    async def _try_fallback(
        self,
        step: ChainStep,
        chain_id: str,
        target: str,
        options: dict[str, Any],
    ) -> StepResult:
        """Try executing with fallback tool."""
        result = StepResult(
            step_id=step.id,
            tool=step.fallback_tool,
            status=StepStatus.RUNNING,
            started_at=datetime.now(),
        )

        logger.info(f"Trying fallback tool: {step.fallback_tool}")

        try:
            tool = await plugin_registry.get_instance(step.fallback_tool)
            plugin_result = await tool.execute(target, options)

            if plugin_result.success:
                result.status = StepStatus.COMPLETED
                result.data = plugin_result.data

                # Emit step completed with fallback note
                event_bus.emit(
                    Events.CHAIN_STEP_COMPLETED,
                    {
                        "chain_id": chain_id,
                        "step_id": step.id,
                        "tool": step.fallback_tool,
                        "fallback": True,
                        "duration": (datetime.now() - result.started_at).total_seconds(),
                    },
                )
            else:
                result.status = StepStatus.FAILED
                result.errors = plugin_result.errors

        except Exception as e:
            result.status = StepStatus.FAILED
            result.errors.append(f"Fallback failed: {e}")

        result.ended_at = datetime.now()
        result.duration = (result.ended_at - result.started_at).total_seconds()

        return result

    def _build_execution_order(
        self, steps: list[ChainStep]
    ) -> list[list[ChainStep]]:
        """Build topologically sorted execution groups.

        Returns list of step groups. Steps in same group can run in parallel.

        Raises:
            ChainExecutionError: If cycles or unreachable steps detected
        """
        step_map = {s.id: s for s in steps}
        all_step_ids = set(step_map.keys())

        # Validate parallel_with references
        for step in steps:
            for peer_id in step.parallel_with:
                if peer_id not in step_map:
                    raise ChainExecutionError(
                        f"Step '{step.id}' has parallel_with reference to unknown step '{peer_id}'"
                    )

        # Build dependency graph
        dependencies: dict[str, set[str]] = defaultdict(set)
        dependents: dict[str, set[str]] = defaultdict(set)

        for step in steps:
            for dep in step.depends_on:
                if dep not in step_map:
                    raise ChainExecutionError(
                        f"Step '{step.id}' depends on unknown step '{dep}'"
                    )
                dependencies[step.id].add(dep)
                dependents[dep].add(step.id)

        # Validate parallel_with: peers must have same dependencies satisfied
        for step in steps:
            if step.parallel_with:
                for peer_id in step.parallel_with:
                    peer = step_map[peer_id]
                    # Check that peer doesn't depend on this step (would create ordering conflict)
                    if step.id in dependencies[peer_id]:
                        raise ChainExecutionError(
                            f"Step '{peer_id}' cannot be parallel_with '{step.id}' "
                            f"because it depends on it"
                        )

        # Topological sort with cycle detection (Kahn's algorithm)
        in_degree = {s.id: len(dependencies[s.id]) for s in steps}
        ready = [s for s in steps if in_degree[s.id] == 0]
        completed: set[str] = set()
        order: list[list[ChainStep]] = []

        while ready:
            # Group steps that can run in parallel
            parallel_group: list[ChainStep] = []
            added_to_group: set[str] = set()
            next_ready: list[ChainStep] = []

            for step in ready:
                if step.id in added_to_group:
                    continue

                # Check if all dependencies are complete
                if all(d in completed for d in dependencies[step.id]):
                    parallel_group.append(step)
                    added_to_group.add(step.id)

                    # Add parallel peers if their deps are also satisfied
                    for peer_id in step.parallel_with:
                        if peer_id not in added_to_group and peer_id not in completed:
                            peer = step_map[peer_id]
                            if all(d in completed for d in dependencies[peer_id]):
                                parallel_group.append(peer)
                                added_to_group.add(peer_id)
                else:
                    next_ready.append(step)

            if parallel_group:
                order.append(parallel_group)
                for step in parallel_group:
                    completed.add(step.id)
                    # Decrease in-degree of dependents and add to ready if 0
                    for dep_id in dependents[step.id]:
                        in_degree[dep_id] -= 1
                        if in_degree[dep_id] == 0:
                            dep_step = step_map[dep_id]
                            if dep_step not in next_ready:
                                next_ready.append(dep_step)

            ready = next_ready

        # Check for cycles or unreachable steps
        if len(completed) != len(all_step_ids):
            missing = all_step_ids - completed
            # Determine if it's a cycle or unreachable
            # If remaining steps all have unsatisfied deps pointing to each other, it's a cycle
            raise ChainExecutionError(
                f"Chain has cycles or unreachable steps. "
                f"Steps not executed: {', '.join(sorted(missing))}"
            )

        return order

    def _resolve_target(
        self, step: ChainStep, chain_target: str | None
    ) -> str | None:
        """Resolve target for step."""
        # Try target binding first
        if step.target_binding:
            value = self._resolve_binding(step.target_binding)
            if value:
                if isinstance(value, list):
                    return ",".join(str(v) for v in value)
                return str(value)

        # Then static target
        if step.target_static:
            return step.target_static

        # Then chain target
        if chain_target:
            return chain_target

        # Finally context target
        if self.context and self.context.target:
            return self.context.target

        return None

    def _resolve_options(self, step: ChainStep) -> dict[str, Any]:
        """Resolve all options including data bindings."""
        options = dict(step.options)

        for binding in step.option_bindings:
            value = self._resolve_binding(binding)
            if value is not None:
                options[binding.target_option] = value
            elif binding.required:
                raise ValueError(
                    f"Required binding not found: {binding.source_step}.{binding.source_path}"
                )
            elif binding.default is not None:
                options[binding.target_option] = binding.default

        return options

    def _resolve_binding(self, binding: DataBinding) -> Any:
        """Resolve a single data binding."""
        if binding.source_step not in self._step_results:
            return binding.default

        source_data = self._step_results[binding.source_step].data
        value = resolve_path(source_data, binding.source_path)

        if value is None:
            return binding.default

        # Apply transform
        if binding.transform:
            if callable(binding.transform):
                value = binding.transform(value)
            elif isinstance(binding.transform, str):
                transform_fn = get_transform(binding.transform)
                if transform_fn:
                    value = transform_fn(value)

        return value

    def _evaluate_condition(self, condition: Condition) -> bool:
        """Evaluate step condition."""
        if condition.source_step not in self._step_results:
            result = False
        else:
            data = self._step_results[condition.source_step].data
            value = resolve_path(data, condition.path)

            if condition.check == "exists":
                result = value is not None
            elif condition.check == "count_gt":
                result = isinstance(value, (list, tuple)) and len(value) > condition.value
            elif condition.check == "count_lt":
                result = isinstance(value, (list, tuple)) and len(value) < condition.value
            elif condition.check == "value_eq":
                result = value == condition.value
            elif condition.check == "value_ne":
                result = value != condition.value
            elif condition.check == "has_key":
                result = isinstance(value, dict) and condition.value in value
            elif condition.check == "contains":
                result = condition.value in (value or [])
            else:
                result = False

        return not result if condition.negate else result

    def _aggregate_outputs(self, chain: ChainDefinition) -> dict[str, Any]:
        """Aggregate outputs from all steps."""
        output = {}

        for step in chain.steps:
            if step.id in self._step_results:
                result = self._step_results[step.id]
                if result.status == StepStatus.COMPLETED:
                    key = step.output_key or step.id
                    output[key] = result.data

        return output

    def _get_step(self, chain: ChainDefinition, step_id: str) -> ChainStep | None:
        """Get step by ID."""
        for step in chain.steps:
            if step.id == step_id:
                return step
        return None

    async def cancel(self) -> None:
        """Cancel the running chain."""
        self._cancelled = True

        # Emit cancellation event
        if self._current_chain_id:
            self._emit_chain_cancelled(self._current_chain_id)

        for task in self._running_tasks.values():
            task.cancel()

        # Wait for tasks to complete
        if self._running_tasks:
            await asyncio.gather(
                *self._running_tasks.values(),
                return_exceptions=True,
            )

        self._running_tasks.clear()

    def get_step_result(self, step_id: str) -> StepResult | None:
        """Get result for a specific step."""
        return self._step_results.get(step_id)

    def get_all_results(self) -> dict[str, StepResult]:
        """Get all step results."""
        return dict(self._step_results)
