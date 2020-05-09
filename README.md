# livecode-webdavlib-tsnet


WebDavLib (tsNet version) is a library for accessing WebDAV servers using the LiveCode tsNet external.

##### WebDavLib currently supports the following WebDAV methods:

-   OPTIONS
-   PROPFIND
-   HEAD
-   GET
-   PUT
-   DELETE
-   MKCOL
-   PROPPATCH
-   LOCK
-   UNLOCK


##### Examples of tasks the library allows to accomplish:

-   Generate a list of all WebDAV methods provided by the server
-   Get the file size, modification date, content type etc. of a remote file
-   Download a file
-   Check write permission of a directory
-   Upload a file
-   Delete a file / folder
-   List files / folders
-   Create a folder
-   Set custom file properties
-   Get custom file properties
-   Remove custom file properties
-   Lock a file (may be not supported on NextCloud servers)
-   Check if a file is locked
-   Unlock a file (may be not supported on NextCloud servers)

WebDavLib is tested on a commercial NextCloud server, on a private NextCloud server and on a local WebDAV server.


### Getting Started

Check out the enclosed sample stack "webDavTest". Fill out the form and execute the request handler by choosing a method from the option menu (top to bottom) and clicking on "Request".


### Usage

Basically the procedure to send a WebDAV request involves:

-   Setting up the request data using an array
-   Storing the request data in WebDavLib which returns a request ID
-   Sending the request to the server to receive a response

Following is an example (returning the WebDAV methods the server supports):

```
-- SETUP REQUEST DATA
put "myname.mynextcloudserver.com" into tRequestDataA["host"]
put "myname" into tRequestDataA["username"]
put "mypassword" into tRequestDataA["password"]
put "LiveCode" && the version && "(" & the platform &  ")" into tRequestDataA["user_agent"]
put TRUE into tRequestDataA["asynchronous"]
put TRUE into tRequestDataA["verifySSLPeer"]
put "/remote.php/webdavdirectory/" into tRequestDataA["uri"]
put "https://" & tRequestDataA["host"] & tRequestDataA["uri"] into tRequestDataA["url"]
put fld "davDirFld" into tRequestDataA["uri"]

-- STORE REQUEST DATA IN LIBRARY, GET REQUEST ID
wdlSetupNewRequest tRequestDataA
put the result into tReqID

-- SEND REQUEST TO SERVER
put wdlGetserverMethods(tReqID) into tServerResponse

wdlCleanup tReqID
```

These are the request data array keys used depending on the particular request method:

-   host (the host address like: myname.ocloud.de)
-   uri (the path to the WebDAV directory like: /remote.php/webdav/)
-   port (as a general rule this is 80 or 443 for secure connections)
-   username
-   password (user password or app password)
-   authType (Basic or Digest)
-   sslFlag (a boolean, TRUE for a secure connection)
-   user_agent (User-agent)
-   nameSpace (WebDAV XML namespace like "http://www.w3.com/standards/z39.50/")
-   lockOwner (any name)
-   lockToken (the cCurrentLockToken of stack "WebDavLib")
-   callBack (the name of a callback handler used by methods GET and PUT)
-   callbackTarget (the long ID of the object containing the callback handler)
-   all tsNet settings relevant for the particular transfer type


Following are the available public handlers:

-   wdlSetupNewRequest tRequestDataA
-   wdlGetserverMethods(tReqID)
-   wdlGetFile(tReqID)
-   wdlWritePermission(tReqID)
-   wdlDeleteFileFolder(tReqID)
-   wdlPutFile(tReqID)
-   wdlGetFileList(tReqID)
-   wdlCreateFolder(tReqID)
-   wdlSetFileProps(tReqID, tSetPropsA, tRemovePropsA)
-   wdlGetFileProps(tReqID, tProps)
-   wdlGetCustomProps(tReqID, tProps)
-   wdlLock(tReqID)
-   wdlUnlock(tReqID)
-   wdlGetFileHeaders(tReqID)
-   wdlCleanup tReqID


**NOTE:** Be aware that this library requires the LC Indy Edition or the LC Business Edition.


### Meta

-   Version: 1.0.3
-   Author:  [Ralf Bitter](mailto:rabit@revigniter.com)
