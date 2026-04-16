This project is meant to help VT AutoNav easily visualize data.

Main script is AutoNavDataAnalysis.prj - launch this to have the app pop up
There is a GUI in the App Folder called TestingGUI that lets users choose what data they want to see

To get data from the robot run this command (on your computer, not the container nor the jetson):

`scp -r jetson:~/AutoNav_25-26/logs ~/Downloads/logs`

This assumes that "jetson" has been setup in your .ssh/config.
