# Window Animation Diagnostics

Timing diagnostics are disabled by default. To enable them for a local session, quit Arson and launch the installed executable from Terminal:

```bash
ARSON_ANIMATION_DIAGNOSTICS=1 /Applications/Arson.app/Contents/MacOS/Arson
```

Record this process with Instruments using the Points of Interest instrument. Filter for subsystem `de.lukasharzbecker.arson` and category `WindowAnimation`.

Intervals cover the complete window action, animation, individual frame updates, and Accessibility calls. Events record display callbacks, replaced buffered ticks, processing times, updates skipped by the existing resize throttle, and completion or cancellation. The data contains timing values and flags; it does not include window titles or application content.

Accessibility call completion does not establish when the target application presented its new frame. Compare these intervals with rendering data before attributing a pause to Arson, the target application, or hardware.

Quit and reopen Arson normally to disable diagnostics again. Enabling diagnostics does not change interpolation, animation duration, or resize pacing.
