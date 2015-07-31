# README

## How does it work?

### Chrome extension

The Chrome extension (packaged in **extension.crx**) must be installed into Chrome browser. It will send HTTP requests to the Dispatcher, then receive and display the response.

### Dispatcher daemon

The Dispatcher daemon is a ruby script continuously running and listening on port 7500 using a lightweight HTTP server. It executes the command ordered by the Chrome extension either in the local host (commands using Sencha CMD) or in the VM (backend tasks) via SSH.

## Getting started 
1. Clone this repo somewhere on your computer.
2. Install the Chrome extension in your browser:
   * Open [chrome://extensions/](chrome://extensions/) in Chrome.
   * Drag & drop the file **extension.crx** in the page, then confirm the installation.
3. Configure the Dispatcher daemon:
   * Open the file **/daemons/lib/core.rb** and make sure the variable **PROME_DIR** points to your Prome directory.
   _Should be the path relative to your home directory._
4. Install Ruby dependencies:
   * Open the terminal, navigate to the extension directory.
   * Run the following command:
   ```
   bundle install
   ```
   _The Ruby version should be 2.1.3+_
5. [Install Sencha CMD](https://docs.sencha.com/cmd/5.x/intro_to_cmd.html) on your computer (the local host machine, not the VM).
6. Launch the daemon:
   * Open the terminal, navigate to the extension directory.
   * Runs the following commands in your Terminal to launch the Dispatcher.
   ```
   ruby dispatcher.rb start
   ```
    This command must be run each time you restart the computer. You can also restart or get the status of the daemon using **restart|status** instead of **start**.
7. Open a Prome website in your browser, then launch Chrome Developer tools. There is now a new panel named **Prome**.

## Using the devtools panel

### Launch a task
   * Click on a task to display the task tab.
   * Click **Send command** or double-click on a task name to launch a task.

_You can launch multiple tasks in parallel. When all tasks complete, the page will reload automatically. Also the extension will always clear the cache before reloading. If the database is recreated, the extension will log you out from Prome._

### Tenant-aware
The panel automatically recognizes which tenant you are connected to using the URL subdomain.  
_Each command sent to the Dispatcher will be executed for this tenant._

You can have multiple tabs open for different tenants. However, keep in mind that if you send a Sencha command, it will be executed for the tenant in the current tab.

### Which tasks to run when you...
_Tasks should be run simultaneously._

#### ... checkout a Git branch
   * Back-end - reset setup
   * Front-end - build all

#### ... open a tab for a different tenant
   * Back-end - load tenant fixtures (if not already done)
   * Front-end - build all

#### ... add web resources (images, fonts)
   * Resources - copy

#### ... update SASS files
   * SASS - compile

#### ... add/remove JS file(s)
   * Javascript - refresh index

#### ... test in production (locally)
   * Front-end - build all
   * Back-end - clear cache

## Troubleshooting

### Request failed

If the Dispatcher daemon is not running (or crashed), a command executed in Chrome devtools panel will promptly display a "Request failed" message. Just runs the launch command for the Dispatcher daemon to fix the problem.

### Request hanging after computer restart

Make sure the Dispatcher daemon is running by executing this command in the extension directory:
```
ruby dispatcher.rb status
```
If no instance is active, just runs the launch command for the Dispatcher daemon to fix the problem.
