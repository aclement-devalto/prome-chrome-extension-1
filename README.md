# README

## How does it work?

### Chrome extension

The Chrome extension (packaged in **extension.crx**) must be installed into Chrome browser. It will send HTTP requests to the Command listener, then receive and display the response.

### Command listener

The Command listener is a ruby script continuously running and listening on port 7500 using a lightweight HTTP server. It executes the command ordered by the Chrome extension either in the local host (commands using Sencha CMD) or in the VM (backend tasks) via SSH.

## Getting started 

1. Install Chrome extension in your browser:
   * Open [chrome://extensions/](chrome://extensions/) in Chrome.
   * Drag & drop the file **extension.crx** in the page, then confirm the installation.

2. Configure the Command Listener:
   * Open the file **command-listener.rb** and make sure the variable **prome_dir** points to your Prome directory.  
   _Should be the path relative to your home directory._
3. Launch the Command Listener:
   * Open the terminal, navigate to the extension directory.
   * Runs the following command in your Terminal to launch the Command listener.  
   _This command must be run each time you restart the computer._
```
./command-listener.rb
```
4. Open a Prome website in your browser, then launch Chrome Developer tools. There is now a new panel named **Prome**.

## Using the devtools panel

* The panel automatically recognizes which tenant you are connected to using the URL subdomain.  
_Each command sent to the Command Listener will be executed for the current tenant._

* Click on a task to display the task tab.
* Click **Send command** or double-click on a task name to launch a task.
* You can launch multiple tasks in parallel.
* When all tasks completed, the page will reload automatically.

## Troubleshooting

### Request failed

If the Command listener is not running (or crashed), a command executed in Chrome devtools panel will promptly display a "Request failed" message. Just runs the launch command for the Command listener to fix the problem.