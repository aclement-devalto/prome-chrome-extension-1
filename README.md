# README

## How does it work?

### Chrome extension

The Chrome extension (packaged in **extension.crx**) must be installed into Chrome browser. It will send HTTP requests to the Dispatcher, then receive and display the response.

### Dispatcher daemon

The Dispatcher daemon is a ruby script continuously running and listening on port 7500 using a lightweight HTTP server. It executes the command ordered by the Chrome extension either in the local host (commands using Sencha CMD) or in the VM (backend tasks) via SSH.

### File watcher daemon (in development)

The file watcher daemon is a ruby script continuously running and watching JS and SCSS files in the web directory. It will automatically rebuild the JS/SASS files when a change is detected, then ask the browser to reload the corresponding tabs. This daemon is still in development and is not required by the Chrome extension.

## Getting started 

1. Install Chrome extension in your browser:
   * Open [chrome://extensions/](chrome://extensions/) in Chrome.
   * Drag & drop the file **extension.crx** in the page, then confirm the installation.
2. Configure the Dispatcher daemon:
   * Open the file **/daemons/lib/core.rb** and make sure the variable **PROME_DIR** points to your Prome directory.
   _Should be the path relative to your home directory._
3. Install Ruby dependencies:
   * Run the following command in the extension directory:
   ```
   bundle install
   ```
   _The Ruby version should be 2.1.3+_
4. Launch the daemon:
   * Open the terminal, navigate to the extension directory.
   * Runs the following commands in your Terminal to launch the Dispatcher.
   ```
   ruby dispatcher.rb start
   ```
    This command must be run each time you restart the computer. You can also restart or get the status of both daemons using **restart|status** instead of **start**._
5. Open a Prome website in your browser, then launch Chrome Developer tools. There is now a new panel named **Prome**.

## Using the devtools panel

* The panel automatically recognizes which tenant you are connected to using the URL subdomain.  
_Each command sent to the Dispatcher will be executed for the current tenant._

* Click on a task to display the task tab.
* Click **Send command** or double-click on a task name to launch a task.
* You can launch multiple tasks in parallel.
* When all tasks completed, the page will reload automatically.
* The file watcher daemon will rebuild Prome each time a JS file is added/removed from web directory or a SCSS file is modified. The build will be done for the last built tenant. All tabs corresponding to this tenant in the browser will then be automatically reloaded.

## Troubleshooting

### Request failed

If the Dispatcher daemon is not running (or crashed), a command executed in Chrome devtools panel will promptly display a "Request failed" message. Just runs the launch command for the Dispatcher daemon to fix the problem.
