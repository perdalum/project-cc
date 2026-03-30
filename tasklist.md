# changes

- [x] All date properties e.g., Modified should include time
- [x] all date and time properties should in the UI use the date format from Systemsettings but off course sort correctly. So make sure to dicern between internal datetime and UI
- [x] add Created property to the Project Property View
- [x] Touched property should display the datetime of the latest value
- [x] each row should show the latest Note
- [x] The Folder property should be displayed as 📁. Click opens the folder
- [x] The Terminal property should be displayed as 🐚. Click opens the folder in Terminal
- [x] The Project List View should have the following properties in this sequence: Folder, Terminal, Name, State, Next, Touched, Note. The rest of the properties should be managed in the Project Property View

- [x] in Project List View: make all columns sortable
- [x] in Project List View: when click on the Next property for a project, open a date-time selector widget and set this property
- [x] Add mandatory comment to state changes to Rejected
- [x] in Project List View: when click on the Note property for a project, open a prompt for a short text and update the Note list (datetime and note)

- [x] implement the Folder property. Create a method for attaching a Finder folder to a project using macOS folder selector widget.
- [x] use the method to add a folder in the Project Property View

- [x] in Project List View: The Folder property should for each project row be displayed as 📁. Click opens the folder. If no folder has been configured, prompt for one at set the property to that.
- [x] Add "New Folder" to the folder picker
- [x] Change folder icon to Finder icon instead of the UTF8 one
- [x] Change to the Terminal.app icon
- [x] in Project List View: The Terminal property should for each project be displayed as 🐚 Click opens the folder in Terminal
- [x] in Project List View: Add the URL property.
- [x] The URL property should for each project be displayed as the Safari icon. Click opens the URL in default browser

- [x] Add new virtual states to the state dropdown selector: init: {New, Idea}, Not done: {Idea, New, Active, Delegated, Waiting}, Started: {Active, Delegated, Waiting}, {Done {Rejected, Done}. Make the filter use these virtual or grouped states.

- [x] In Project List View: if the Next value is before today, the field background should be light red
- [x] In Project List View: if the Next value is within the next three days, the field background should be light orange
- [x] In Project List View: if the Next value is today, the field background should be light light green

- [x] In the Next date picker add a Clear button

- [x] make the width of the columns persistent
- [x]  Also evaluate how hard it would be to be able to move/shift the columns around in the UI and persist a given configuration
- [x] add the same dynamic datetime formating as seen in e.g. the Finder, where the datetime format is reflected by the width of the field 

- [x] make the rows selectable using standard SwiftUI. Come up with suggestions on how to do this, as most fields in a row have an action attached.
- [x] when they are selectable, make the following functions apply to the selected rows by two-finger click/Ctrl-click: touch, set next, clear next, set state, delete

- [x] ensure all changes to any property of a project results in an update of Touched and Modified properties.

implement keyboard driven flow

- [x] return key opens Project Property View
- [x] ESC and Command F moves to Filter field. ESC in Filter field moves keyboard focus to list
- [x] Cmd N: new project
- [x] Cmd M: new note
- [x] Cmd T: Touch
- [x] Cmd D: opens State drop down



Refine the Project Property View

- [x] make Add note work
- [x] show a list of all touches
- [ ] add edit note
- [x] when entering a state change note, copy that to Notes



Visualizations

- [x] add visualization

- [x] implement import fra Project C&C
- [ ] make the diagram scrollable (previous unit, next unit, smooth scroll)
- [ ] add x-labels to top
- [ ] make sortable on # touches
- [ ] add legend for color scale





Setup

- [x] Add a Settings view (standard macOS settings) with the following settings: Persistent storage folder for the JSON file.



New Views

- Review View



- [x] Add app icon

- [ ] make folders machine agnostic

- [ ] Leaving Delegated and Waiting should also have mandatory comments



## Dissimination

- [x] write a good README
- [x] add license
- [ ] write a blog post for website
- [x] make mock data