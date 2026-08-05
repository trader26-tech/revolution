# Bobo mascot — Rive drop-in slot

To upgrade Bobo from the built-in code-drawn fallback to a professional,
Duolingo-quality animated mascot:

1. Design & rig **Bobo** in the Rive editor (https://rive.app).
2. Add a **State Machine** named `Bobo` with these inputs:
   - `mood` — a **Number** input: `0` = happy, `1` = excited, `2` = sleepy.
   - `poke` — a **Trigger** fired when the user taps Bobo.
3. Export as a runtime `.riv` and save it here as **`bobo.riv`**.
4. Re-add the `rive` package (`flutter pub add rive`) and switch
   `BoboMascot` to the Rive-backed implementation (the widget is already
   structured so this is a localized change — see
   `lib/features/mascot/presentation/bobo_mascot.dart`).

Until `bobo.riv` exists, the app renders the code-drawn fallback, so nothing
breaks if this folder only contains this README.
