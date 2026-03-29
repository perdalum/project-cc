---
title: Specification of Project Command And Control
date: 2026-03-29
author: Per Møldrup-Dalum
---

# Specification of Project Command And Control

## concepts

*Project:* A project can be a classical project that can be completed, an area of responsibility

A Project have a set of properties that each have a type. Each property can be user writable UW or only user readable UR. 

Name: <string> project name

*Category:* <string> A category is a container of *projects*. Examples: CHC, Arts, AU, Ego, Family.

Project type: Either *Classical project* or *Area of responsibility*

State: one of {Idea, New, Active, Delegated, Waiting, Rejected, Done}. State changes are recorded in:

Log: list of {<date>, <old state>, <new state>, <comment>}, where <comment> is mandatory for changes to and from Delegated (who is this delegated to) and Waiting (why is it waiting and what is it waiting for)

Start: <date>

End <date>:

Modified <date>:

Folder: a folder in macOS Finder

Notes: list of {<date>, <text>}

Touched: list of  <date>:

Latest Review: <date>:

Next: <date>

URL: <url>

Goal: <text>

## Data model

The persistence of the data is done using a JSON file stored at a configurable folder. Each update is immidiately written to this file. When the program starts, this file is read.

## UI

The UI consists of two main screens (more will be added later):

* Project List View: list of all projects
* Project Property View: screen to show, read and edit the properties for a specific project.
* Overview View

### Project List View

The Project List lists all projects with a select set of properties in a table form UI. Each property can be used to sort the list by clicking on the property column header. Use the type of the property to sort by, e.g., dates, numbers, and strings.

Some UW properties also have a function attached to clicking the specific property for a project (a row). E.g. clicking Touched will add "now" to the list of dates for this property. 

The following are the functions to attach to the properties:

* Name: open the Property View of this project in this row
* State: Open a drop down where one can select a new state from {Idea, New, Active, Delegated, Waiting, Rejected, Done}. Record the state change in Log property. If new state is Delegated or Waiting, prompt for the mandatory comment that is also stored in the Log
* Folder: Open the folder in Finder
* Notes: Prompt for a note and store that with {<date>, <text>}
* Touched: Update the list of  <date>
* Next: Prompt for a new date to write in this property
* URL: Open the URL
* Goal: Open the text in a new window for editing plain text.

This UI screen also have calculated fields:

Terminal: open the Finder folder in the Terminal application

At the top of this UI screen we have:

a Filter: text field that filters the list by searching the Name for the text. Simple Boolean expressions: use - for NOT, | for OR. AND is implicit

I also need to be able to filter the list by State.

### Project Property View

This view will display all properties of a project in a nice, functional, and beautiful way.

This view will enable the user to edit all UW properties using native macOS widgets.

### Overview View

This will be a graphical overview of the projects in a kind of calendar heat map showing each update, change, touch of each project.

This view will have same filtering options as the Project List View.