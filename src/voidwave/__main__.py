"""Entry point for python -m voidwave."""
import sys


def main():
    """Main entry point."""
    from voidwave.cli import app

    # Import here to avoid circular imports and allow quick --version
    try:
        app()
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
