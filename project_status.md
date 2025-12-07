# ChordScan Project Status

## Current State ("What We Have")

The application is currently a **functional UI prototype** built with Flutter. It validates the user flow but relies on mock data for core functionality.

### Core Architecture
-   **Framework**: Flutter (Dart)
-   **State Management**: `Provider` + `ChangeNotifier` (`AppState`)
-   **Local Storage**: `Hive` (stores detected songs history)
-   **Navigation**: `BottomNavigationBar` with 3 main tabs:
    1.  **Listen**: The main entry point for capturing audio.
    2.  **History**: Displays a list of previously "detected" songs.
    3.  **Song**: Detail view for a specific song and its chords.

### Implemented Features (Mocks)
1.  **Song Detection (`DetectService`)**:
    -   **Current**: Simulates listening with a 2-second delay.
    -   **Logic**: Picks a random song from a hardcoded `mockSongPool`.
    -   **State**: Returns a `Song` object carrying title and artist.

2.  **Chord Generation (`ChordService`)**:
    -   **Current**: Generates random chord progressions.
    -   **Logic**: Returns a string with suggested chords, randomized BPM, and strumming patterns after a 600ms delay.
    -   **State**: `generateChordsWithAI` throws an `UnimplementedError`.

3.  **UI/UX**:
    -   Basic "Listening" animation (button state change).
    -   SnackBar notifications for success/failure.
    -   History list persistence.

## Missing Features ("What We Need")

To turn this prototype into a real "Shazam for Chords", we need to replace the mocks with actual audio processing and analysis components.

### 1. Audio Capture & Pre-processing
-   **Microphone Access**: Implement `flutter_sound` or `record` package to capture real audio from the device microphone.
-   **Audio Stream Management**: Handle permissions (iOS `Info.plist`, Android `AndroidManifest.xml`) and real-time audio buffering.

### 2. Song Identification (The "Shazam" part)
-   **Fingerprinting**: We need a way to identify the song.
-   **Options**:
    -   **Integration**: Integrate with an external API like **ACRCloud**, **ShazamKit**, or **AudD**.
    -   **Custom**: Build a backend service that accepts audio snippets and matches them against a database.
    -   **Algorithm**: Implement audio fingerprinting if building from scratch (complex).

### 3. Chord Recognition (The "Chord" part)
-   **DSP / ML Engine**: We need an algorithm to extract chords from the audio signal.
    -   **Real-time Analysis**: Fast Fourier Transform (FFT) or Constant-Q Transform (CQT) to identify frequencies and chroma features.
    -   **Classification**: A classifier (Machine Learning model) to map chroma vectors to chord names (Example: C Major, G7, etc.).
-   **Syncing**: Aligning the detected chords with the song's timeline.

### 4. Backend & API
-   **External Data**: If not analyzing raw audio for chords on the fly, we need an API that provides chord data for the identified song (e.g., fetching from Ultimate Guitar or a similar database).

### 5. UI Improvements
-   **Audio Visualization**: Replace the simple spinner with a real-time waveform or frequency visualizer.
-   **Real-time Feedback**: Show chords scrolling in real-time as the music plays (if real-time detection is implemented).

## Technical Roadmap
1.  **Research**: Choose between External API (easier, paid) vs. On-Device DSP (harder, free/offline).
2.  **Audio Implementation**: Replace `DetectService` logic with real microphone stream handling.
3.  **Integration**: Connect the audio stream to the chosen analysis engine.
4.  **Data Layer**: Update `Song` model to store real chord data/timestamps.
