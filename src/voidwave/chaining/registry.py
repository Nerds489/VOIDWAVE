"""Chain registry for managing reusable chain definitions."""

import copy
from typing import Iterator

from voidwave.chaining.models import ChainDefinition, ChainStep
from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class ChainRegistry:
    """Registry for managing reusable chain definitions."""

    def __init__(self) -> None:
        self._chains: dict[str, ChainDefinition] = {}
        self._tags: dict[str, set[str]] = {}

    def register(self, chain: ChainDefinition) -> None:
        """Register a chain definition.

        Args:
            chain: Chain definition to register
        """
        self._chains[chain.id] = chain

        # Index by tags
        for tag in chain.tags:
            if tag not in self._tags:
                self._tags[tag] = set()
            self._tags[tag].add(chain.id)

        logger.debug(f"Registered chain: {chain.id} ({chain.name})")

    def unregister(self, chain_id: str) -> bool:
        """Unregister a chain by ID.

        Args:
            chain_id: Chain ID to unregister

        Returns:
            True if chain was found and removed
        """
        if chain_id not in self._chains:
            return False

        chain = self._chains.pop(chain_id)

        # Remove from tag index
        for tag in chain.tags:
            if tag in self._tags:
                self._tags[tag].discard(chain_id)

        return True

    def get(self, chain_id: str) -> ChainDefinition | None:
        """Get a chain by ID.

        Args:
            chain_id: Chain ID to retrieve

        Returns:
            Chain definition or None if not found
        """
        return self._chains.get(chain_id)

    def get_by_tag(self, tag: str) -> list[ChainDefinition]:
        """Get all chains with a specific tag.

        Args:
            tag: Tag to filter by

        Returns:
            List of matching chain definitions
        """
        chain_ids = self._tags.get(tag, set())
        return [self._chains[cid] for cid in chain_ids if cid in self._chains]

    def list_all(self) -> list[ChainDefinition]:
        """List all registered chains.

        Returns:
            List of all chain definitions
        """
        return list(self._chains.values())

    def list_ids(self) -> list[str]:
        """List all chain IDs.

        Returns:
            List of chain IDs
        """
        return list(self._chains.keys())

    def list_tags(self) -> list[str]:
        """List all tags in use.

        Returns:
            List of tags
        """
        return list(self._tags.keys())

    def compose(self, *chain_ids: str, new_id: str | None = None) -> ChainDefinition:
        """Compose multiple chains into a single chain.

        Steps from later chains depend on all steps from earlier chains.

        Args:
            *chain_ids: IDs of chains to compose
            new_id: Optional ID for composed chain

        Returns:
            New composed chain definition

        Raises:
            KeyError: If any chain ID is not found
        """
        if not chain_ids:
            raise ValueError("At least one chain ID required")

        steps: list[ChainStep] = []
        prev_step_ids: list[str] = []
        all_tags: set[str] = set()

        for chain_id in chain_ids:
            chain = self.get(chain_id)
            if chain is None:
                raise KeyError(f"Chain not found: {chain_id}")

            all_tags.update(chain.tags)

            for step in chain.steps:
                # Deep copy to avoid modifying original
                new_step = copy.deepcopy(step)

                # Prefix step ID to avoid collision
                new_step.id = f"{chain_id}.{step.id}"

                # Update depends_on with prefixed IDs
                new_step.depends_on = [
                    f"{chain_id}.{dep}" for dep in step.depends_on
                ]

                # Add dependency on previous chain's last steps
                if prev_step_ids and not new_step.depends_on:
                    new_step.depends_on = prev_step_ids.copy()

                # Update bindings with prefixed step IDs
                if new_step.target_binding:
                    new_step.target_binding.source_step = (
                        f"{chain_id}.{new_step.target_binding.source_step}"
                    )

                for binding in new_step.option_bindings:
                    binding.source_step = f"{chain_id}.{binding.source_step}"

                if new_step.condition:
                    new_step.condition.source_step = (
                        f"{chain_id}.{new_step.condition.source_step}"
                    )

                steps.append(new_step)

            # Track last steps for next chain's dependencies
            prev_step_ids = [f"{chain_id}.{s.id}" for s in chain.steps]

        composed_id = new_id or f"composed_{'_'.join(chain_ids)}"

        return ChainDefinition(
            id=composed_id,
            name=f"Composed: {', '.join(chain_ids)}",
            description=f"Composed chain from: {', '.join(chain_ids)}",
            steps=steps,
            tags=list(all_tags) + ["composed"],
        )

    def extend(
        self,
        base_chain_id: str,
        additional_steps: list[ChainStep],
        new_id: str | None = None,
    ) -> ChainDefinition:
        """Extend an existing chain with additional steps.

        Args:
            base_chain_id: ID of chain to extend
            additional_steps: Steps to add
            new_id: Optional new ID

        Returns:
            New extended chain definition

        Raises:
            KeyError: If base chain not found
        """
        base = self.get(base_chain_id)
        if base is None:
            raise KeyError(f"Chain not found: {base_chain_id}")

        # Deep copy base steps
        steps = [copy.deepcopy(s) for s in base.steps]

        # Get last step IDs for dependency
        last_step_ids = [s.id for s in base.steps]

        # Add new steps with dependency on last steps
        for step in additional_steps:
            new_step = copy.deepcopy(step)
            if not new_step.depends_on:
                new_step.depends_on = last_step_ids.copy()
            steps.append(new_step)

        extended_id = new_id or f"{base_chain_id}_extended"

        return ChainDefinition(
            id=extended_id,
            name=f"{base.name} (Extended)",
            description=f"Extended version of {base.name}",
            steps=steps,
            tags=base.tags + ["extended"],
            target_type=base.target_type,
            preflight_action=base.preflight_action,
        )

    def __contains__(self, chain_id: str) -> bool:
        """Check if chain is registered."""
        return chain_id in self._chains

    def __len__(self) -> int:
        """Get number of registered chains."""
        return len(self._chains)

    def __iter__(self) -> Iterator[ChainDefinition]:
        """Iterate over registered chains."""
        return iter(self._chains.values())


# Singleton registry
chain_registry = ChainRegistry()
