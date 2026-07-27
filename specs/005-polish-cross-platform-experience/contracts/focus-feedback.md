# UI and Service Contract: Focus Feedback

## Settings

The Focus settings interface uses concise English labels:

```text
Feedback
Notifications        [toggle]
Sounds               [toggle]
Focus complete       [picker] [Test]
Break complete       [picker] [Test]
```

Rules:

- Both toggles default to on.
- Focus complete defaults to Glass.
- Break complete defaults to Bell.
- Pickers and Test controls remain visible but disabled while Sounds is off.
- Test plays the current selection without changing timer state or posting a
  notification.
- Reset to Defaults restores all four feedback values.
- No explanatory footer is required for these controls.

## Feedback Matrix

| Event | Sounds off | Sounds on | Notifications off | Notifications on |
|---|---|---|---|---|
| Start/resume | No audio | One Start cue | No notification | No notification |
| Pause | No audio | One Pause cue | No notification | No notification |
| Explicit end | No audio | One End cue | No notification | No notification |
| Focus complete | No audio | One selected Focus cue | No banner | One silent banner |
| Break complete | No audio | One selected Break cue | No banner | One silent banner |
| Test | No audio | One selected cue | No notification | No notification |

When both toggles are on, a completion produces one selected cue and one silent
banner. The notification itself never adds a second sound.

## Timer-to-Feedback Interface

`FocusTimer` emits only effective `FocusFeedbackEvent` values to an injected
`FocusFeedbackHandling` dependency.

The handler:

- reads current Focus feedback preferences;
- sends at most one sound request;
- sends at most one notification request for a completion;
- swallows and logs adapter failures;
- never mutates timer state.

No feedback is emitted for:

- starting an already-running timer;
- pausing an already-paused timer;
- ending while idle;
- extending a phase;
- changing durations;
- an internal reset or session replacement;
- the silent internal stop used when auto-continue is off.

## Sound Playback

- Assets are bundled and available in both app targets.
- Playback uses AVFoundation.
- Cues are brief and non-looping.
- The app owns at most one active Focus cue at a time.
- iPhone playback uses an ambient, mixing session.
- Missing or invalid audio is logged and otherwise ignored.

## Notification Isolation

- Focus notification settings are read only from `FocusSettings`.
- Memory schedule and location notification preferences remain unchanged.
- Permission denial or a post failure cannot block the timer or sound.
- Focus notifications use their existing concise English titles and bodies.
