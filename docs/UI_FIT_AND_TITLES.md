# Menus and major titles

Menus retain the existing navy panels, character cards, town columns and world
controls. Long inventories and complete wrapped text use bounded Previous/Next
pages. No ScrollContainer, ItemList scroll area or scrolling slot popup remains.
Locked characters are filtered before pagination. A partially filled character
page shrinks to its current cards instead of retaining empty rows or columns.

Android controls use the actual DisplayServer safe area mapped through the
viewport screen transform. At 480 DPI and 1.5 physical pixels per logical unit,
the measured profile uses 96 logical units for touch targets, 32 for body text
and 28 for secondary text. These correspond to 48 dp targets and 16 sp body
text. Higher density reduces page capacity rather than capping target size.
The compact character view shares one pinned navigation/Info/Close footer.
Info pages retain all explanations and available character descriptions.
Escape returns from Info to the roster before closing the overlay.

Town assembly keeps its foundation/action/component columns. Move includes
unplaced foundations, so recovered structures can reach the placement preview
and Confirm action even in the compact layout. Remove remains disabled until
the selected structure is placed. Walking dialogue releases and hides the
joystick; closing the dialogue restores it without replaying a touch.

The Windows root configures its native window once: normal 1280 by 720,
uniformly reduced only when the usable work area requires it, fixed resize
border, enabled native Maximize/Restore and Minimize. Re-entering a manager
preserves an already maximized window. There is no custom window chrome or
continuous resize correction loop.

Only biome entry and character unlock use the noninteractive word title.
Eight reusable word labels reveal with a small rise and stagger; longer titles
use one wrapped label. At most one active and one pending title exist. Unlock
preempts an obsolete biome title. Duplicate entry keys, retries and return from
town do not replay announcements. Startup waits for save restoration before
announcing the restored floor. Leaving for town, death and teardown cancel
owned tweens. The exported `animate_titles` option presents static text instead.

The native SVG design plans were rendered before visual changes. Validation
artifacts and command outcomes are recorded outside the source tree in
`outputs/Fit-menus-and-titles-results.txt`. Android evidence is emulator evidence;
no physical Galaxy S24 Ultra or physical-phone performance has been measured.
Portrait layout and later town rewards, ranged attacks, cores and bosses are
outside this slice.
