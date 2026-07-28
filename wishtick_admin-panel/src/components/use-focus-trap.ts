import { useEffect, type RefObject } from 'react';

const FOCUSABLE = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

/**
 * Keeps Tab inside an open overlay.
 *
 * Without this, Tab walks straight out of a modal into the page behind it —
 * which axe cannot detect (the markup is correct; the behaviour is not) but
 * which strands a keyboard or screen-reader user outside a dialog they cannot
 * see they have left. `aria-modal` tells assistive tech the rest is inert; only
 * a trap makes that true for the keyboard.
 *
 * Also restores focus to whatever was focused before the overlay opened.
 */
export function useFocusTrap(
  containerRef: RefObject<HTMLElement | null>,
  active: boolean,
  onEscape?: () => void,
): void {
  useEffect(() => {
    if (!active) return;

    const container = containerRef.current;
    if (!container) return;

    const previouslyFocused = document.activeElement as HTMLElement | null;

    const focusable = () =>
      Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
        (element) => element.offsetParent !== null || element === document.activeElement,
      );

    // Move focus in. Prefer the first field over the first button, so a dialog
    // with an input does not open with the destructive action focused.
    const initial =
      container.querySelector<HTMLElement>('input:not([type="hidden"]), textarea, select') ??
      focusable()[0];
    initial?.focus();

    // Captured once so the closure below has a non-null reference.
    const trapped = container;

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        onEscape?.();
        return;
      }
      if (event.key !== 'Tab') return;

      const elements = focusable();
      if (elements.length === 0) {
        event.preventDefault();
        return;
      }

      const first = elements[0]!;
      const last = elements[elements.length - 1]!;
      const current = document.activeElement;

      if (event.shiftKey && (current === first || !trapped.contains(current))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && (current === last || !trapped.contains(current))) {
        event.preventDefault();
        first.focus();
      }
    }

    document.addEventListener('keydown', onKeyDown, true);

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    return () => {
      document.removeEventListener('keydown', onKeyDown, true);
      document.body.style.overflow = previousOverflow;
      previouslyFocused?.focus();
    };
  }, [active, containerRef, onEscape]);
}
