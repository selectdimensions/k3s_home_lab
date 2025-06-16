param(
  [string]$cmd = "command run 'whoami'",
  [string]$inventory = "inventory.yaml",
  [string]$targets = "all",
  [string]$workdir = ""
)

# Set working directory - default to puppet if not specified and cmd contains plan/task
if (-not $workdir) {
  if ($cmd -match "^(plan|task)") {
    $workdir = "puppet"
  } else {
    $workdir = "."
  }
}

# Build the complete docker command as a single string
$dockerCmd = "docker run --rm -it " +
  "-w /home/boltuser/workspace/$workdir " +
  "-v ${PWD}:/home/boltuser/workspace " +
  "-v C:\Users\Jenkins\.bolt-ssh:/home/boltuser/.ssh " +
  "-e BOLT_GEM=true " +
  "-e BOLT_PROJECT=/home/boltuser/workspace/$workdir " +
  "puppet-bolt $cmd"

# Add targets and inventory if specified
if ($targets -and $targets -ne "") {
  $dockerCmd += " --targets $targets"
}
if ($inventory -and $inventory -ne "") {
  # Use the inventory path as-is since it's relative to the workspace mount
  $dockerCmd += " --inventoryfile $inventory"
}

# Execute the command
Invoke-Expression $dockerCmd
