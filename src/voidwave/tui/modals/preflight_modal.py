"""Preflight check modal for showing requirements and auto-fixing."""

from textual.app import ComposeResult
from textual.containers import Container, Vertical, Horizontal
from textual.screen import ModalScreen
from textual.widgets import Button, Label, Static, OptionList
from textual.widgets.option_list import Option

from voidwave.automation.engine import PreflightResult, RequirementStatus
from voidwave.automation.preflight import PreflightChecker
from voidwave.automation.labels import AUTO_REGISTRY
from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class PreflightModal(ModalScreen[bool]):
    """Modal for displaying preflight check results and fixing issues."""

    CSS = """
    PreflightModal {
        align: center middle;
    }

    PreflightModal > Container {
        width: 70;
        height: auto;
        max-height: 80%;
        background: #1a1a2e;
        border: solid #e94560;
        padding: 1 2;
    }

    PreflightModal .title {
        text-align: center;
        text-style: bold;
        color: #e94560;
        padding-bottom: 1;
    }

    PreflightModal .subtitle {
        text-align: center;
        color: #6c7086;
        padding-bottom: 1;
    }

    PreflightModal .requirement-list {
        height: auto;
        max-height: 15;
        border: solid #3a3a5e;
        margin: 1 0;
    }

    PreflightModal .status-met {
        color: #00ff00;
    }

    PreflightModal .status-fixable {
        color: #ffaa00;
    }

    PreflightModal .status-missing {
        color: #ff0000;
    }

    PreflightModal .buttons {
        height: auto;
        align: center middle;
        padding-top: 1;
    }

    PreflightModal Button {
        margin: 0 1;
    }

    PreflightModal #fix-all {
        background: #e94560;
    }

    PreflightModal #cancel {
        background: #3a3a5e;
    }
    """

    def __init__(self, result: PreflightResult, session=None) -> None:
        super().__init__()
        self.result = result
        self.session = session
        self.checker = PreflightChecker(session)

    def compose(self) -> ComposeResult:
        with Container():
            yield Label(f"⚠ Preflight Check: {self.result.action}", classes="title")

            if self.result.all_met:
                yield Label("All requirements satisfied!", classes="subtitle status-met")
            else:
                yield Label("Some requirements need attention:", classes="subtitle")

            # Show requirements list
            with Vertical(classes="requirement-list"):
                for req in self.result.requirements:
                    status = self._get_status(req)
                    icon = self._get_icon(status)
                    color_class = f"status-{status.value}"
                    yield Static(
                        f"{icon} {req.name}: {req.description}",
                        classes=color_class
                    )

            # Buttons
            with Horizontal(classes="buttons"):
                if self.result.fixable:
                    yield Button("Fix All", id="fix-all", variant="primary")
                if self.result.all_met or not self.result.missing:
                    yield Button("Continue", id="continue", variant="success")
                yield Button("Cancel", id="cancel", variant="default")

    def _get_status(self, req) -> RequirementStatus:
        """Get the status of a requirement."""
        if req in self.result.fixable:
            return RequirementStatus.FIXABLE
        elif req in self.result.missing or req in self.result.manual:
            return RequirementStatus.MISSING
        return RequirementStatus.MET

    def _get_icon(self, status: RequirementStatus) -> str:
        icons = {
            RequirementStatus.MET: "✓",
            RequirementStatus.FIXABLE: "⚡",
            RequirementStatus.MISSING: "✗",
            RequirementStatus.MANUAL: "⚠",
        }
        return icons.get(status, "?")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "fix-all":
            await self._fix_all()
        elif event.button.id == "continue":
            self.dismiss(True)
        elif event.button.id == "cancel":
            self.dismiss(False)

    async def _fix_all(self) -> None:
        """Attempt to fix all fixable requirements."""
        self.app.notify("Fixing requirements...", severity="information")

        fixed_count = 0
        for req in self.result.fixable[:]:
            try:
                success = await self._try_fix(req)
                if success:
                    fixed_count += 1
                    self.result.fixable.remove(req)
            except Exception as e:
                logger.warning(f"Failed to fix {req.name}: {e}")

        if fixed_count > 0:
            self.app.notify(f"Fixed {fixed_count} requirement(s)", severity="information")

        # Re-check and update UI
        new_result = await self.checker.check(self.result.action)
        self.result = new_result

        if new_result.all_met:
            self.dismiss(True)
        else:
            # Refresh the modal
            await self.recompose()

    async def _try_fix(self, req) -> bool:
        """Try to fix a single requirement."""
        if req.auto_label:
            handler_class = AUTO_REGISTRY.get(req.auto_label)
            if handler_class:
                try:
                    # Some handlers need parameters
                    if req.auto_label == "AUTO-INSTALL":
                        handler = handler_class(tool_name=req.name)
                    elif req.auto_label == "AUTO-IFACE":
                        handler = handler_class(required_type="wireless")
                    else:
                        handler = handler_class()

                    if await handler.can_fix():
                        return await handler.fix()
                except Exception as e:
                    logger.warning(f"Handler {req.auto_label} failed: {e}")

        # Try requirement's own fix
        if req.fix:
            try:
                import asyncio
                return await asyncio.to_thread(req.fix)
            except Exception as e:
                logger.warning(f"Fix method failed for {req.name}: {e}")

        return False


class InterfaceSelectModal(ModalScreen[str | None]):
    """Modal for selecting a network interface."""

    CSS = """
    InterfaceSelectModal {
        align: center middle;
    }

    InterfaceSelectModal > Container {
        width: 60;
        height: auto;
        max-height: 70%;
        background: #1a1a2e;
        border: solid #00d9ff;
        padding: 1 2;
    }

    InterfaceSelectModal .title {
        text-align: center;
        text-style: bold;
        color: #00d9ff;
        padding-bottom: 1;
    }

    InterfaceSelectModal OptionList {
        height: auto;
        max-height: 10;
        margin: 1 0;
    }

    InterfaceSelectModal .buttons {
        height: auto;
        align: center middle;
        padding-top: 1;
    }
    """

    def __init__(self, interfaces: list, title: str = "Select Interface") -> None:
        super().__init__()
        self.interfaces = interfaces
        self.modal_title = title
        self.selected: str | None = None

    def compose(self) -> ComposeResult:
        with Container():
            yield Label(self.modal_title, classes="title")

            options = []
            for iface in self.interfaces:
                if isinstance(iface, dict):
                    name = iface.get("name", str(iface))
                    detail = iface.get("type", "")
                    mac = iface.get("mac", "")
                    label = f"{name} [{detail}] {mac}"
                elif hasattr(iface, "name"):
                    label = f"{iface.name} [{iface.type}] {iface.mac}"
                    name = iface.name
                else:
                    label = str(iface)
                    name = str(iface)
                options.append(Option(label, id=name))

            yield OptionList(*options, id="interface-list")

            with Horizontal(classes="buttons"):
                yield Button("Select", id="select", variant="primary")
                yield Button("Cancel", id="cancel", variant="default")

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        self.selected = event.option.id

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "select":
            if self.selected:
                self.dismiss(self.selected)
            else:
                self.app.notify("Please select an interface", severity="warning")
        elif event.button.id == "cancel":
            self.dismiss(None)


class InputModal(ModalScreen[str | None]):
    """Generic input modal for getting user input."""

    CSS = """
    InputModal {
        align: center middle;
    }

    InputModal > Container {
        width: 60;
        height: auto;
        background: #1a1a2e;
        border: solid #00d9ff;
        padding: 1 2;
    }

    InputModal .title {
        text-align: center;
        text-style: bold;
        color: #00d9ff;
        padding-bottom: 1;
    }

    InputModal Input {
        margin: 1 0;
    }

    InputModal .buttons {
        height: auto;
        align: center middle;
        padding-top: 1;
    }
    """

    def __init__(self, title: str, placeholder: str = "", password: bool = False) -> None:
        super().__init__()
        self.modal_title = title
        self.placeholder = placeholder
        self.password = password

    def compose(self) -> ComposeResult:
        from textual.widgets import Input

        with Container():
            yield Label(self.modal_title, classes="title")
            yield Input(
                placeholder=self.placeholder,
                password=self.password,
                id="input-field"
            )
            with Horizontal(classes="buttons"):
                yield Button("OK", id="ok", variant="primary")
                yield Button("Cancel", id="cancel", variant="default")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        from textual.widgets import Input

        if event.button.id == "ok":
            input_widget = self.query_one("#input-field", Input)
            value = input_widget.value.strip()
            if value:
                self.dismiss(value)
            else:
                self.app.notify("Please enter a value", severity="warning")
        elif event.button.id == "cancel":
            self.dismiss(None)


class ConfirmModal(ModalScreen[bool]):
    """Simple confirmation modal."""

    CSS = """
    ConfirmModal {
        align: center middle;
    }

    ConfirmModal > Container {
        width: 50;
        height: auto;
        background: #1a1a2e;
        border: solid #ffaa00;
        padding: 1 2;
    }

    ConfirmModal .title {
        text-align: center;
        text-style: bold;
        color: #ffaa00;
        padding-bottom: 1;
    }

    ConfirmModal .message {
        text-align: center;
        padding: 1 0;
    }

    ConfirmModal .buttons {
        height: auto;
        align: center middle;
        padding-top: 1;
    }
    """

    def __init__(self, title: str, message: str) -> None:
        super().__init__()
        self.modal_title = title
        self.message = message

    def compose(self) -> ComposeResult:
        with Container():
            yield Label(self.modal_title, classes="title")
            yield Static(self.message, classes="message")
            with Horizontal(classes="buttons"):
                yield Button("Yes", id="yes", variant="warning")
                yield Button("No", id="no", variant="default")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "yes")
