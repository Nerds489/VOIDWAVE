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

    async def execute(self, chain: ChainDefinition, target: str | None = None) -> ChainResult:
        """Execute a complete chain.

        Args:
            chain: The chain definition to execute
            target: Override target for the chain

        Returns:
            ChainResult with all step results
        """
        result = ChainResult(
            chain_id=chain.id,
            success=True,
            started_at=datetime.now(),
        )

        logger.info(f"Starting chain: {chain.name} ({chain.id})")

        # Emit start event
        event_bus.emit(
            Events.TASK_STARTED,
            {
                "task_type": "chain",
                "chain_id": chain.id,
                "chain_name": chain.name,
            },
        )

        # Store target in context if provided
        if target and self.context:
            self.context.target = target

        # Build execution order (topological sort with parallel grouping)
        execution_order = self._build_execution_order(chain.steps)

        # Execute steps in order
        for step_group in execution_order:
            if self._cancelled:
                result.success = False
                result.errors.append("Chain cancelled")
                break

            # Execute group (parallel if multiple)
            group_results = await self._execute_group(step_group, chain, target)

            # Process results
            for step_id, step_result in group_results.items():
                self._step_results[step_id] = step_result
                result.steps[step_id] = step_result

                if step_result.status == StepStatus.FAILED:
                    step = self._get_step(chain, step_id)
                    if step and step.on_error == OnErrorBehavior.STOP:
                        result.success = False
                        result.errors.extend(step_result.errors)
                        result.ended_at = datetime.now()
                        result.total_duration = (
                            result.ended_at - result.started_at
                        ).total_seconds()

                        event_bus.emit(
                            Events.TASK_COMPLETED,
                            {
                                "task_type": "chain",
                                "chain_id": chain.id,
                                "success": False,
                                "error": step_result.errors,
                            },
                        )
                        return result

        # Aggregate final output
        result.final_output = self._aggregate_outputs(chain)
        result.ended_at = datetime.now()
        result.total_duration = (result.ended_at - result.started_at).total_seconds()

        # Store in context
        if self.context:
            self.context.results[chain.id] = result.final_output

        # Emit completion event
        event_bus.emit(
            Events.TASK_COMPLETED,
            {
                "task_type": "chain",
                "chain_id": chain.id,
                "success": result.success,
                "duration": result.total_duration,
            },
        )

        logger.info(
            f"Chain completed: {chain.name} - "
            f"{'success' if result.success else 'failed'} "
            f"({result.total_duration:.2f}s)"
        )

        return result

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
                results[step_id] = StepResult(
                    step_id=step_id,
                    tool=self._get_step(chain, step_id).tool,
                    status=StepStatus.FAILED,
                    errors=[str(e)],
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

        # Check condition
        if step.condition and not self._evaluate_condition(step.condition):
            result.status = StepStatus.SKIPPED
            result.ended_at = datetime.now()
            logger.debug(f"Step skipped (condition not met): {step.id}")
            return result

        # Resolve target
        target = self._resolve_target(step, chain_target)
        if not target:
            result.status = StepStatus.FAILED
            result.errors.append("Could not resolve target")
            result.ended_at = datetime.now()
            return result

        # Resolve options with bindings
        try:
            options = self._resolve_options(step)
        except ValueError as e:
            result.status = StepStatus.FAILED
            result.errors.append(str(e))
            result.ended_at = datetime.now()
            return result

        # Get tool instance
        try:
            tool = await plugin_registry.get_instance(step.tool)
        except KeyError:
            result.status = StepStatus.FAILED
            result.errors.append(f"Tool not found: {step.tool}")
            result.ended_at = datetime.now()
            return result

        # Execute with retry logic
        for attempt in range(step.retry_count + 1):
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
                    return result

                result.errors.extend(plugin_result.errors)

            except asyncio.TimeoutError:
                result.errors.append(f"Timeout after {step.timeout}s")
            except asyncio.CancelledError:
                result.status = StepStatus.FAILED
                result.errors.append("Cancelled")
                result.ended_at = datetime.now()
                return result
            except Exception as e:
                result.errors.append(str(e))
                logger.warning(f"Step {step.id} attempt {attempt + 1} failed: {e}")

            result.retries = attempt

            # Retry delay with exponential backoff
            if attempt < step.retry_count:
                delay = step.retry_delay * (2 ** attempt)
                await asyncio.sleep(delay)

        # Try fallback if available
        if step.fallback_tool and step.on_error == OnErrorBehavior.FALLBACK:
            fallback_result = await self._try_fallback(step, target, options)
            if fallback_result.status == StepStatus.COMPLETED:
                return fallback_result

        result.status = StepStatus.FAILED
        result.ended_at = datetime.now()
        result.duration = (result.ended_at - result.started_at).total_seconds()

        return result

    async def _try_fallback(
        self,
        step: ChainStep,
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
        """
        # Build dependency graph
        step_map = {s.id: s for s in steps}
        dependencies: dict[str, set[str]] = defaultdict(set)
        dependents: dict[str, set[str]] = defaultdict(set)

        for step in steps:
            for dep in step.depends_on:
                if dep in step_map:
                    dependencies[step.id].add(dep)
                    dependents[dep].add(step.id)

        # Find steps with no dependencies
        ready = [s for s in steps if not dependencies[s.id]]
        completed: set[str] = set()
        order: list[list[ChainStep]] = []

        while ready:
            # Group steps that can run in parallel
            parallel_group = []
            next_ready = []

            for step in ready:
                # Check if all dependencies are complete
                if all(d in completed for d in dependencies[step.id]):
                    # Check for parallel_with grouping
                    if step.parallel_with:
                        # Add to current group with parallel peers
                        parallel_group.append(step)
                        for peer_id in step.parallel_with:
                            if peer_id in step_map and peer_id not in completed:
                                peer = step_map[peer_id]
                                if peer not in parallel_group:
                                    parallel_group.append(peer)
                    else:
                        parallel_group.append(step)
                else:
                    next_ready.append(step)

            if parallel_group:
                order.append(parallel_group)
                for step in parallel_group:
                    completed.add(step.id)
                    # Add dependents to ready list
                    for dep_id in dependents[step.id]:
                        if dep_id in step_map:
                            dep_step = step_map[dep_id]
                            if dep_step not in next_ready and dep_id not in completed:
                                next_ready.append(dep_step)

            ready = next_ready

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
