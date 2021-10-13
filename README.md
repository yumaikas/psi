# Psi: A polling filesystem watcher implemented in PowerShell

## Usage

After cloning this repo, copy `psi.ps1` onto your $PATH. 

Then you can run commands like so from a Powershell prompt:

```ps1
psi -dirs script.ps1 { ./script.ps1 | % { Write-Host $_ } }
```

The extra Write-Host is because long-running jobs, or servers don't tend to flush the output pipeline by default, from what I've seen.

## Notes/intended scenarios

Because this works as a polling tool, it's not intenteded for watching directories with tens of thousands of files. That being said, it does re-run on the first change it detects, and assumes that *any* change represents a full stop/restart of the script block. I've found it very useful for use with scripts that use Invoke-WebRequest to test API endpoints for example. 

It's been tested in mostly-interactive scenarios, not at running for extended time in the background.

It does make it easy to build up a list of files without having to worry about how many instances of the FileSystemWatcher class it might spin up and lock up Kernel Memory.

The Polling design was based on a similar tactic being used by esbuild, though this watcher polls the entire file list every second.


## Feedback

Feel free to open an issue here!
