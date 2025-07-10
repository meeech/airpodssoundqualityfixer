# AirPods Sound Quality Fixer And Battery Life Enhancer For MacOS

Fixes sound quality drops when using AirPods with Macs. 
It forces the default audio input to be the built-in microphone instead of AirPods' microphone so MacOS doesn't have to mix down the output. 
It also increases battery life because AirPods doesn't have to broadcast sound back.
If you have more input devices you can select which device you want to force over the AirPods microphone.

The app runs in the menu bar.

Download the compiled application from [releases](https://github.com/milgra/airpodssoundqualityfixer/releases/tag/1.0)

## Building and Installing from Source

If you prefer to build the application yourself, follow these steps:

1.  **Open the Project:**
    *   Open `AirPods Sound Quality Fixer.xcodeproj` in Xcode.

2.  **Archive the Project:**
    *   In the Xcode menu, select `Product` > `Archive`. This will build the project for release.

3.  **Distribute the App:**
    *   Once the build is complete, Xcode's Organizer window will appear. Select your new archive from the list.
    *   Click the **"Distribute App"** button.

4.  **Select Distribution Method:**
    *   Choose **"Direct Distribution"** and click "Next".

5.  **Choose Destination:**
    *   Select the **"Copy App"** option and click "Next".

6.  **Export the App:**
    *   Xcode will ask where you want to save the exported application (`.app`). Choose a location like your Desktop.
    *   Click **"Export"**.

7.  **Install the App:**
    *   Navigate to the location where you exported the app.
    *   Drag the `AirPods Sound Quality Fixer.app` file into your Mac's `/Applications` folder.
