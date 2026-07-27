# UI Contract: Desktop Experience

## Primary Content Width

The main content column has a maximum width of 880 points and remains centered
when more horizontal space is available.

| Surface | 880-point column | Full-width exception |
|---|---:|---:|
| Calendar Day list | Yes | No |
| Mind overview | Yes | No |
| Mind detail | Yes | No |
| Focus canvas | Yes | No |
| Me dashboard | Yes | No |
| Calendar Month grid | No | Yes |
| Window toolbar and bottom navigation | No | Yes |
| Native Settings and popovers | No | Yes |

Internal horizontal padding is included within the 880-point footprint.
Background surfaces may continue filling the window.

## Desktop Tab Selection

```text
tap unselected tab -> select destination
tap selected Mind  -> clear Mind path and transient Mind context
tap selected Me    -> clear Me path
tap selected Calendar -> preserve date and mode
tap selected Focus    -> preserve session
```

Requirements:

- A path of any depth clears in one activation.
- Repeating the action at root is a no-op.
- Reselection never edits or deletes user data.
- The existing selection animation applies only when the destination changes.
- Command-key destination shortcuts follow the same selection behavior.

## Calendar Day Scrolling

- The content remains a native `List`.
- Mouse wheel, trackpad, keyboard, and accessibility scrolling remain enabled.
- The vertical indicator visibility is `.never` on Mac Calendar Day.
- Empty, short, and long Day states never show the vertical scrollbar.
- iPhone retains its existing Calendar behavior.

## Accessibility and Input

- Every desktop tab remains keyboard reachable and exposes its selected trait.
- Root reselection has no additional confirmation or explanatory copy.
- Width changes do not clip content at the minimum 980×680 window size.
