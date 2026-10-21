// No argument: the menu bar app (what Finder and login items launch). Any argument: the command line.
if CommandLine.arguments.count > 1 {
    command(Array(CommandLine.arguments.dropFirst()))
}
MenuBar.run()
