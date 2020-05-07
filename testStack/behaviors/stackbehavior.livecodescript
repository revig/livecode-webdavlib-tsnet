script "WebDavTestStackBehavior"



local sBarName, sCurrentFileSize, sContacted
local sAuthorizationRequested, sProgBarInitialized, sKeepLogData
local sCurrentHeader, sCurrentRemoteFileURL, sBusyCursor
-----------------------------------------------------------


----------------------------------------------
# REQUEST HANDLERS
---------------------------------------------
----------------------------------
## METHOD: OPTIONS
----------------------------------

command options
   local tCallback, tRequestDataA, tReqID, tRequestedData

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put TRUE into tRequestDataA["no_reuse"]
   # OPTIONAL
   put TRUE into tRequestDataA["debugCallback"]
   put TRUE into tRequestDataA["save_sent_headers"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlGetserverMethods(tReqID) into tRequestedData

   # SEE responseWDL IN CASE THE REQUEST IS ASYNCHRONOUS
   if tRequestDataA["asynchronous"] <> TRUE then
      put "wdlGetserverMethods:" && tRequestedData
      wdlCleanup tReqID
   end if
end options



# ASYNCHRONOUS REQUEST RESPONSE
command responseWDL pReqID pResponse pRequestHandler
   local tKey, tFileName, tDestPath, tProp

   if pResponse contains "Error" then
      put cr & cr & pResponse after fld "errorFld"
   else

      switch pRequestHandler
         case "wdlGetserverMethods"
            put pRequestHandler & ":" && pResponse

            break
         case "wdlGetFileProps"
            repeat for each key tKey in pResponse
               if tKey is "getcontentlength" then
                  put pResponse[tKey] into sCurrentFileSize
               end if
               put tKey & ":" && pResponse[tKey] & return after msg
            end repeat

            break
         case "wdlGetFileHeaders"
            if pResponse is an array then
               put pResponse[sCurrentHeader] into sCurrentFileSize
               put sCurrentHeader & ":" && sCurrentFileSize & return after msg
            else
               put "Error:" && pResponse & return after msg
            end if

            break
         case "wdlGetFile"
            ## SUCCESS, SAVE FILE
            set the itemdelimiter to "/"
            put last item of sCurrentRemoteFileURL into tFileName

            put fld "downloadPathFld" & "/" & tFileName into tDestPath

            put pResponse into URL ("binfile:" & tDestPath)

            put return & "downloaded" after msg

            break
         case "wdlPutFile"
            if pResponse contains "Error" then
               put cr & cr & pResponse after fld "errorFld"
            else
               # SUCCESS
               if "201" is in line 1 of pResponse then
                  put "Request ID" && pReqID & ": created" & cr after fld "statusFld"
               end if

               put "Upload response:" && pResponse
            end if

            break
         case "wdlDeleteFileFolder"
            if pResponse contains "Error" then
               put cr & cr & pResponse after fld "errorFld"
            else
               # SUCCESS
               if "204" is in line 1 of pResponse then
                  put "Request ID" && pReqID & ": deleted" & cr after fld "statusFld"
               end if

               put "Delete response:" && pResponse
            end if

            break
         case "wdlGetFileList"
            writeToLogWDL pReqID, pResponse
            put "creationdate" into tProp
            put XMLtoFileList(pResponse, tProp)

            break
         case "wdlCreateFolder"
            if "201" is in line 1 of pResponse then
               put "Request ID" && pReqID & ": created" & cr after fld "statusFld"
            end if

            put "Create folder response:" && pResponse
      end switch
   end if -- if pResponse contains "Error" then

   wdlCleanup pReqID
end responseWDL




   ----------------------------------
   ## METHOD: PROPFIND
   ----------------------------------

command fileSize
   local tProps, tCallback, tNameSpace
   local tFilePropValuesAtRequestDataA, tReqID, tFilePropValuesA

   put empty into msg

   libUrlSetStatusCallback

   # GET PROPERTY
   # LEAVE EMPTY TO GET ALL PROPERTIES
   put "getcontentlength" into tProps
   -- put "creationdate" into tProps
   -- put "getcontentlength,getlastmodified" into tProps

   # CUSTOM PROPERTIES
   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   -- put quote & fld "namespaceFld" & quote into tNameSpace
   -- put "authors,testTag" into tProps
   # USE propname TO RETREIVE ALL PROPERTY NAMES
   -- put "propname" into tProps
   -----------
   --   put wdlPropertyNamesXMLdata(tProps, FALSE) into tPropsXML
   --   put tPropsXML
   --   exit to top
   ----------
   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put tRequestDataA["url"] & fld "remoteFileFld" into tRequestDataA["url"]

   put TRUE into tRequestDataA["no_reuse"]
   # OPTIONAL
   put TRUE into tRequestDataA["debugCallback"]
   put TRUE into tRequestDataA["save_sent_headers"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlGetFileProps(tReqID, tProps) into tFilePropValuesA

   # SEE responseWDL IN CASE THE REQUEST IS ASYNCHRONOUS
   if tRequestDataA["asynchronous"] <> TRUE then
      put empty into msg
      repeat for each key tKey in tFilePropValuesA
         put tKey & ":" && tFilePropValuesA[tKey] & return after msg
      end repeat

      wdlCleanup tReqID

      return tFilePropValuesA["getcontentlength"]
   end if
end fileSize




command fileList
   local tCallback, tRequestDataA, tReqID
   local tResponseData, tProp

   libUrlSetStatusCallback

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA


   put TRUE into tRequestDataA["no_reuse"]
   put "Depth: 1" into tRequestDataA["headers"]
   # OPTIONAL
   put TRUE into tRequestDataA["debugCallback"]
   put TRUE into tRequestDataA["save_sent_headers"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlGetFileList(tReqID) into tResponseData

   # SEE responseWDL IN CASE THE REQUEST IS ASYNCHRONOUS
   if tRequestDataA["asynchronous"] <> TRUE then
      writeToLogWDL tReqID, tResponseData
      put "creationdate" into tProp
      # GET FILE / FOLDER PATHS AND CREATION DATES (MODIFICATION DATES)
      put XMLtoFileList(tResponseData, tProp)

      wdlCleanup tReqID
   end if
end fileList



function XMLtoFileList pXMLdata pProp
   local tStartLineNum, tEndLineNum, tFilesListXML, tFilesListA
   local tTheKeys, tKey, tFileFolder, tDate, tFileList

   put lineOffset("<?xml", pXMLdata) into tStartLineNum
   put lineOffset("</D:multistatus>", pXMLdata) into tEndLineNum
   put line tStartLineNum to tEndLineNum of pXMLdata into tFilesListXML

   put convertXMLToArray(tFilesListXML, , ) into tFilesListA
   --------------------------
   -- put printArray("theArray", tFilesListA)
   -- put the keys of tFilesListA["multistatus"]
   -- put the keys of tFilesListA["multistatus"]["response[23]"]["propstat"]["prop"]
   --------------------------
   put the keys of tFilesListA["multistatus"] into tTheKeys

   repeat for each line tKey in tTheKeys
      put tFilesListA["multistatus"][tKey]["href"] into tFileFolder
      if line -1 of tFileFolder is empty then next repeat

      if pProp <> empty then
         if pProp is "creationdate" then
            put tFilesListA["multistatus"][tKey]["propstat"]["prop"]["creationdate"] into tDate
            if tDate is empty then
               put tFilesListA["multistatus"][tKey]["propstat[1]"]["prop"]["creationdate"] into tDate
            end if
            if tDate <> empty then
               put "CD:" && tDate into tDate
            end if

            if tDate is empty then
               put tFilesListA["multistatus"][tKey]["propstat"]["prop"]["getlastmodified"] into tDate
            end if
            if tDate is empty then
               put tFilesListA["multistatus"][tKey]["propstat[1]"]["prop"]["getlastmodified"] into tDate
            end if

            if tDate <> empty then
               put "MD:" && tDate into tDate
            end if

            put tDate && "--" && tFileFolder & return after tFileList
         else
            put tFileFolder & return after tFileList
         end if -- if pProp is "creationdate"
      else
         put tFileFolder & return after tFileList
      end if -- if pProp <> empty
   end repeat

   return tFileList
end XMLtoFileList






command getProperties
   local tFile, tNameSpace, tProps, tCallback
   local tOmitTsNet, tRequestDataA, tReqID, tFilePropValuesA
   local tKey, tTheResult

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   # GET PROPERTY
   # LEAVE EMPTY TO GET ALL PROPERTIES
   -- put "creationdate" into tProps
   -- put "getcontentlength" into tProps
   -- put "creationdate,getcontentlength" into tProps

   # CUSTOM PROPERTIES
   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   put quote & fld "namespaceFld" & quote into tNameSpace

   # LEAVE tProps EMPTY TO RETREIVE ALL PROPERTY NAMES AND ALL PROPERTY VALUES
   -- put "authors,testTag" into tProps
   -- put "authors" into tProps
   -- put "testTag" into tProps
   put "testTag,Author" into tProps

   # USE propname TO RETREIVE ALL PROPERTY NAMES, REQUIRES EMPTY NAMESPACE
   --   put empty into tNameSpace
   --   put "propname" into tProps

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   put tFile into tRequestDataA["uri"]
   # CUSTOM PROPERTIES
   put tNameSpace into tRequestDataA["nameSpace"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   # REQUEST
   put wdlGetCustomProps(tReqID, tProps) into tFilePropValuesA

   wdlCleanup tReqID

   repeat for each key tKey in tFilePropValuesA
      put tKey & ":" && tFilePropValuesA[tKey] & return after tTheResult
   end repeat

   if tTheResult is empty then
      if the number of items of tProps is 1 then
         put "Property not set."
      else
         put "Properties not set."
      end if
   else
      put tTheResult -- & return & return & tFilePropValues
   end if
end getProperties




command checkLocked
   local tFile, tProps, tCallback, tOmitTsNet
   local tRequestDataA, tReqID, tFilePropValuesA, tKey, tTheResult

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   # USE tNameSpace ONLY FOR CUSTOM PROPERTIES
   put "lockdiscovery" into tProps

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   put tFile into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   # REQUEST
   put wdlGetFileProps(tReqID, tProps, tOmitTsNet) into tFilePropValuesA

   wdlCleanup tReqID

   repeat for each key tKey in tFilePropValuesA
      put tKey & ":" && tFilePropValuesA[tKey] & return after tTheResult
   end repeat

   if tTheResult is empty then
      if the number of items of tProps is 1 then
         put "Property not set."
      else
         put "Properties not set."
      end if
   else
      put tTheResult -- & return & return & tFilePropValuesA
   end if
end checkLocked

--------------------------------



----------------------------------
## METHOD: GET
----------------------------------

command downloadFile
   local tFile, tDownloadFile = ""
   local tDestPath, tCallback, tRequestDataA, tReqID
   local tData, tFileName

   put empty into msg

   put fld "downloadPathFld" into tDestPath
   if tDestPath is empty then
      answer error "No download folder specified!"
      exit to top
   end if

   if the optionkey is not down then
      put true into tDownloadFile
   end if

   put empty into sCurrentFileSize

   fileSize
   if the hilite of btn "asynchronousBtn" <> TRUE then
      put the result into sCurrentFileSize
   else
      wait until (sCurrentFileSize <> empty) with messages
   end if

   if sCurrentFileSize is an integer then
      prepareLogFields

      put FALSE into tCallback
      put commonSettings(tCallback) into tRequestDataA

      put tRequestDataA["url"] & fld "remoteFileFld" into tRequestDataA["url"]
      put tRequestDataA["url"] into sCurrentRemoteFileURL

      put TRUE into tRequestDataA["no_reuse"]
      #OPTIONAL
      put TRUE into tRequestDataA["debugCallback"]
      put TRUE into tRequestDataA["save_sent_headers"]

      wdlSetupNewRequest tRequestDataA
      put the result into tReqID

      if tRequestDataA["asynchronous"] <> TRUE then
         put TRUE into sBusyCursor
      else
         put FALSE into sBusyCursor
      end if
      prepareProgress

      # REQUEST
      put wdlGetFile(tReqID) into tData

      if tRequestDataA["asynchronous"] <> TRUE then
         if tData contains "Error" then
            put cr & cr & tData after fld "errorFld"
         else
            ## SUCCESS, SAVE FILE
            set the itemdelimiter to "/"
            put last item of tRequestDataA["url"] into tFileName

            put fld "downloadPathFld" & "/" & tFileName into tDestPath

            put tData into URL ("binfile:" & tDestPath)

            put "downloaded"
         end if -- if tData contains "Error"

         wdlCleanup tReqID

      end if-- if tRequestDataA["asynchronous"] <> TRUE
   end if -- if sCurrentFileSize is an integer
end downloadFile

----------------------------------



----------------------------------
## METHOD: PUT
----------------------------------

command checkWritePermission
   local tCallBack, tOmitTsNet, tRequestDataA, tFile
   local tReqID, tServerResponse, tDeleteResult

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   put "writeTest.txt" into tFile
   put fld "davDirFld" into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   # REQUEST
   put wdlWritePermission(tReqID) into tServerResponse

   wdlCleanup tReqID

   # RESPONSE
   if tServerResponse contains "Error" then
      put cr & cr & tServerResponse after fld "errorFld"
   else -- success
      # CHECKING WRITE PERMISSIONS, SO KEEP LOG DATA OF PUT METHOD
      put TRUE into sKeepLogData

      put deleteFileFolder(tFile, tReqID) into tDeleteResult
   end if

   if not the hilite of btn "asynchronousBtn" then
      put "can write response:" && line 1 of tServerResponse & "," && "delete response:" && tDeleteResult
   else
      put "can write response:" && line 1 of tServerResponse
   end if
end checkWritePermission




command uploadFile
   local tFilePath, tFile, tCallback, tRequestDataA
   local tReqID, tServerResponse

   put fld "filePathFld" into tFilePath

   # GET SIZE OF FILE TO UPLOAD
   getLocalFileSize tFilePath

   set the itemdelimiter to "/"
   put last item of tFilePath into tFile

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put tFilePath into tRequestDataA["filePath"]
   put tRequestDataA["url"] & the secs & "_" & tFile into tRequestDataA["url"]
   put tRequestDataA["url"] into fld "fileToDeleteFld"

   put TRUE into tRequestDataA["no_reuse"]
   # OPTIONAL
   put TRUE into tRequestDataA["debugCallback"]
   put TRUE into tRequestDataA["save_sent_headers"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   if tRequestDataA["asynchronous"] <> TRUE then
      put TRUE into sBusyCursor
   else
      put FALSE into sBusyCursor
   end if
   prepareProgress

   # REQUEST
   put wdlPutFile(tReqID) into tServerResponse

   if tRequestDataA["asynchronous"] <> TRUE then
      if tServerResponse contains "Error" then
         put cr & cr & tServerResponse after fld "errorFld"
      else
         # SUCCESS
         if "201" is in line 1 of tServerResponse then
            put "Request ID" && tReqID & ": created" & cr after fld "statusFld"
         end if
      end if -- if tServerResponse contains "Error"

      put "Upload response:" && tServerResponse

      wdlCleanup tReqID

   end if-- if tRequestDataA["asynchronous"] <> TRUE
end uploadFile

---------------------------------




----------------------------------
## METHOD: DELETE
----------------------------------

command deleteFile
   local tFile, tReqID, tServerResponse

   put fld "fileToDeleteFld" into tFile

   put deleteFileFolder(tFile, tReqID) into tServerResponse

   if tRequestDataA["asynchronous"] <> TRUE then
      if tServerResponse contains "Error" then
         put cr & cr & tServerResponse after fld "errorFld"
      else
         # SUCCESS
         if "204" is in line 1 of tServerResponse then
            put "Request ID" && tReqID & ": deleted" & cr after fld "statusFld"
         end if
      end if -- if tServerResponse contains "Error"

      wdlCleanup tReqID

      put "Delete response:" && tServerResponse

   end if-- if tRequestDataA["asynchronous"] <> TRUE
end deleteFile




function deleteFileFolder pFileFolder @pReqID
   local tCallback, tRequestDataA, tReqID, tServerResponse

   libUrlSetStatusCallback

   if sKeepLogData <> TRUE then
      prepareLogFields
   else
      # CHECKING WRITE PERMISSIONS, SO KEEP LOG DATA OF PUT METHOD
      put FALSE into sKeepLogData
   end if

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   if char 1 to 4 of pFileFolder <> "http" then
      # RELATIVE PATH
      put tRequestDataA["url"] & pFileFolder into tRequestDataA["url"]
   else
      put pFileFolder into tRequestDataA["url"]
   end if

   put TRUE into tRequestDataA["no_reuse"]
   # OPTIONAL
   put TRUE into tRequestDataA["debugCallback"]
   put TRUE into tRequestDataA["save_sent_headers"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID
   put tReqID into pReqID

   # REQUEST
   put wdlDeleteFileFolder(tReqID) into tServerResponse

   return tServerResponse
end deleteFileFolder




command deleteFolder
   local tFolder, tReqID, tServerResponse

   put "testFolder/" into tFolder

   put deleteFileFolder(tFolder, tReqID) into tServerResponse

   if tRequestDataA["asynchronous"] <> TRUE then
      if tServerResponse contains "Error" then
         put cr & cr & tServerResponse after fld "errorFld"
      else
         # SUCCESS
         if "204" is in line 1 of tServerResponse then
            put "Request ID" && tReqID & ": deleted" & cr after fld "statusFld"
         end if
      end if -- if tServerResponse contains "Error"

      put "Delete response:" && tServerResponse

      wdlCleanup tReqID

   end if-- if tRequestDataA["asynchronous"] <> TRUE
end deleteFolder

----------------------------------



----------------------------------
## METHOD: MKCOL
----------------------------------

command createFolder
   local tCallback, tRequestDataA, tReqID, tServerResponse

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put tRequestDataA["url"] & "testFolder/" into tRequestDataA["url"]
   put TRUE into tRequestDataA["no_reuse"]
   # OPTIONAL
   put TRUE into tRequestDataA["debugCallback"]
   put TRUE into tRequestDataA["save_sent_headers"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlCreateFolder(tReqID) into tServerResponse

   if tRequestDataA["asynchronous"] <> TRUE then
      if tServerResponse contains "Error" then
         put cr & cr & tServerResponse after fld "errorFld"
      else
         # SUCCESS
         if "201" is in line 1 of tServerResponse then
            put "Request ID" && tReqID & ": created" & cr after fld "statusFld"
         end if
      end if -- if tServerResponse contains "Error"

      put "Create folder response:" && tServerResponse

      wdlCleanup tReqID
   end if-- if tRequestDataA["asynchronous"] <> TRUE
end createFolder

----------------------------------



----------------------------------
## METHOD: PROPPATCH
----------------------------------

command setProperties
   local tFile, tRemoveProps, tSetProps, tNameSpace

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   -- put "Ralf Bitter,Xaver Bleed,Renglnadders Godhilf" into tSetProps["authors,Author"]
   -- put "Ralf Bitter" into tSetProps["author"]
   ----------
   --   put "foo" into tSetProps[0]["testTag"]
   --   put "Ralf Bitter" into tSetProps[0]["authors"]["Author"]
   --   put "Xaver Bleed" into tSetProps[1]["authors"]["Author"]
   --   put "Renglnadders Godhilf" into tSetProps[2]["authors"]["Author"]
   -----------

   --------
   put "foo" into tSetProps[0]["testTag"]
   put "Ralf Bitter" into tSetProps[1]["Author"]
   ---------

   put empty into tRemoveProps

   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   put quote & fld "namespaceFld" & quote into tNameSpace

   setFileProps tFile, tSetProps, tRemoveProps, tNameSpace
end setProperties




command setFileProps pFile, pSetProps, pRemoveProps, pNameSpace
   local tCallback, tOmitTsNet, tRequestDataA, tReqID

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   put pFile into tRequestDataA["uri"]
   put pNameSpace into tRequestDataA["nameSpace"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   ## REQUEST
   get wdlSetFileProps(tReqID, pSetProps, pRemoveProps)
   put it

   wdlCleanup tReqID
end setFileProps




command removeProperties
   local tFile, tRemoveProps, tSetProps, tNameSpace

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   put empty into tRemoveProps["testTag"]
   put empty into tRemoveProps["Author"]

   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   put quote & fld "namespaceFld" & quote into tNameSpace

   setFileProps tFile, tSetProps, tRemoveProps, tNameSpace
end removeProperties

----------------------------------


----------------------------------
## METHOD: LOCK
----------------------------------

command lockFile
   local tFile, tCallback, tOmitTsNet
   local tRequestDataA, tReqID, tResponse, tResult

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   put tFile into tRequestDataA["uri"]
   put "LCapp" into tRequestDataA["lockOwner"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   # REQUEST
   put wdlLock(tReqID) into tResponse

   if "200" is in line 2 of tResponse then
      put "File" && tFile && "locked." & return & line 1 of tResponse into tResult
   else
      put "Error!" & return & tResponse into tResult
   end if

   writeStatusWDL tReqID, tResult

   put tResult

   wdlCleanup tReqID
end lockFile

----------------------------------



----------------------------------
## METHOD: UNLOCK
----------------------------------

command unlockFile
   local tFile, tCallback, tOmitTsNet, tRequestDataA
   local tReqID, tResponse, tResult

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   # IN CASE YOU KNOW A FILE'S LOCK TOKEN
   -- put "<theLockTokenString>" into tRequestDataA["lockToken"]

   put tFile into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   # REQUEST
   put wdlUnlock(tReqID) into tResponse

   if "204" is in tResponse then
      put "File" && tFile && "unlocked." into tResult
   else
      put "Error!" & return & tResponse into tResult
   end if

   writeStatusWDL tReqID, tResult

   put tResult

   wdlCleanup tReqID
end unlockFile

----------------------------------


----------------------------------
## METHOD: HEAD
----------------------------------

command headerTest
   local tFile

   put "Content-Length" into sCurrentHeader
   put fld "davDirFld" & fld "remoteFileFld" into tFile

   put getFileHeader(tFile, sCurrentHeader)
end headerTest


function getFileHeader pFile pHeader
   local tCallback, tOmitTsNet, tRequestDataA
   local tReqID, tResponseData

   prepareLogFields

   put FALSE into tCallback
   put TRUE into tOmitTsNet
   put commonSettings(tCallback, tOmitTsNet) into tRequestDataA

   put pFile into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA, tOmitTsNet
   put the result into tReqID

   # REQUEST
   put wdlGetFileHeaders(tReqID, , tOmitTsNet) into tResponseData

   wdlCleanup tReqID

   if tResponseData contains "Error" is false then
      return tResponseData[pHeader]
   else
      put cr & cr & tResponseData after fld "errorFld"
      return tResponseData
   end if
end getFileHeader

-------------------------------------


----------------------------------------------
------------------ LOGGING ---------------------

# THESE HANDLERS ARE CALLED BY THE WebDAV LIBRARY
command writeStatusWDL pReqID pStatus
   put "Request ID" && pReqID & ":" && pStatus & cr into pStatus
   put pStatus after fld "statusFld"
end writeStatusWDL




-- command writeToLogWDL pReqID pResponse pSocketToOpen pCurrentRequest
command writeToLogWDL pReqID pResponse tRequestHandler
   local tLogData

   if pResponse is empty then
      -- put "Request ID:" && pReqID && "Socket selected:" && pSocketToOpen & cr & pCurrentRequest & cr & cr into tLogData
      put "Request ID:" && pReqID && "Request handler:" && tRequestHandler & cr & "Response empty." & cr & cr into tLogData
   else
      put pResponse & cr & cr into tLogData
   end if

   put tLogData after fld "logFld"
end writeToLogWDL




command writeErrorWDL pErrorString pSocketID
   local tErrorString

   if pSocketID <> empty then
      put "Socket ID:" && pSocketID & ", " into pSocketID
   end if

   if pErrorString is "401 Authorization Required" then
      put pSocketID & pErrorString & cr into tErrorString
   else
      put pSocketID & "Error:" && pErrorString & cr into tErrorString
   end if

   put tErrorString after fld "errorFld"
end writeErrorWDL
----------------------------------------------------------



command urlCallback pUrl, pStatus
   local tCurrentFileSizeSet, tAmountLoaded, tEndPos

   put (sCurrentFileSize is an integer) into tCurrentFileSizeSet

   if sProgBarInitialized is empty and tCurrentFileSizeSet is TRUE then
      -- put item 3 of pStatus into sCurrentFileSize
      put "upDownloadProgBar" into sBarName
      put false into sContacted
      put false into sAuthorizationRequested
      initializeProgress sBarName, sCurrentFileSize
   end if

   # MOVE SCROLLBAR THUMB
   if tCurrentFileSizeSet is TRUE then
      if the label of btn "authBtn" is "Digest" then
         -- if sAuthorizationRequested is true then
         if pStatus begins with "uploading" or pStatus begins with "loading" then
            put item 2 of pStatus into tAmountLoaded
            doProgress tAmountLoaded, tProgressInterval, sBarName, sCurrentFileSize -- tProgressInterval NOT USED
         end if
         -- end if
      else
         if pStatus begins with "uploading" or pStatus begins with "loading" then
            put item 2 of pStatus into tAmountLoaded
            doProgress tAmountLoaded, tProgressInterval, sBarName, sCurrentFileSize -- tProgressInterval NOT USED
         end if
      end if
   end if

   # WRITE STATUS
   put pStatus & cr after fld "statusFld"

   if the label of btn "authBtn" is "Digest" then
      if item 1 of pStatus is "contacted" then
         put true into sContacted
      end if
      if item 1 of pStatus is "error" and sContacted is true then
         put true into sAuthorizationRequested
      end if
   end if

   # SET END POSITION
   if tCurrentFileSizeSet is TRUE then
      if pStatus is "downloaded" or pStatus is "uploaded" then
         put true into tEndPos
         doProgress sCurrentFileSize, tProgressInterval, sBarName, sCurrentFileSize, tEndPos -- tProgressInterval NOT USED
      end if
   end if
end urlCallback





command prepareLogFields
   local tLogFld, tErrorField, tLogField, tStatusFld

   # SET TARGET FOR LOG MESSAGES
   put the long id of this stack into tLogTarget
   wdlSet "logTarget", tLogTarget

   # EMPTY FIELDS
   put empty into fld "statusFld"
   put empty into fld "logFld"
   put empty into fld "errorFld"
end prepareLogFields




private command prepareProgress pBarName pCallback
   local tCallback

   # PREPARE PROGRESS BAR
   if pCallback is empty then
      put "urlCallback" into tCallback
   else
      put pCallback into tCallback
   end if

   if pBarName is empty then
      put "upDownloadProgBar" into sBarName
   else
      put pBarName into sBarName
   end if

   if sBusyCursor is TRUE then
      set the cursor to busy
   end if

   put empty into sProgBarInitialized
   libUrlSetStatusCallback tCallback, (the long id of this stack)
end prepareProgress



private Command getLocalFileSize pFile
   local tInfo

   if the platform is "MacOS" then
      -- put "byteSize" into tInfo
      put "dataByteSize" into tInfo
      put fileInfoMac(pFile,tInfo) into sCurrentFileSize
   else
      put getFileSize(pFile) into sCurrentFileSize
   end if
end getLocalFileSize



/*----------------------------------------------------------------------
--| COMMAND initializeProgress
--|
--| Author: rabit
--| Version:  1.1
--| Created:  2007-10-08
--| Last Mod: 2008-07-23
--| Requires:  --
--|
--| Summary: Initialize progress bar.
--|
--| Format:  initializeProgress param1, param2
--|
--| Parameters: string <pBarName>, integer <pTotalNum>
--|
--| Return: empty
----------------------------------------------------------------------*/

command initializeProgress pBarName pTotalNum
   # SETUP PROGRESS BAR:
   set the startvalue of sb pBarName to 0
   set the endvalue of sb pBarName to pTotalNum
   set the thumbpos of sb pBarName to 0

   set the visible of scrollbar pBarName to true

   put true into sProgBarInitialized
end initializeProgress





/*----------------------------------------------------------------------
--| COMMAND hideProgress
--|
--| Author: rabit
--| Version:  1.0
--| Created:  2007-10-15
--| Last Mod: --
--| Requires: --
--|
--| Summary: Reset and hide scrollbar.
--|
--| Format:  hideProgress param1
--|
--| Parameters: string <pBarName>
--|
--| Return: empty
----------------------------------------------------------------------*/
command hideProgress pBarName
   -- if there is a image "chasing arrows.gif" then
   -- hide image "chasing arrows.gif"
   -- end if
   set the visible of scrollbar pBarName to false
   set the thumbpos of sb pBarName to 0
end hideProgress




/*----------------------------------------------------------------------
--| COMMAND doProgress
--|
--| Author: rabit
--| Version:  1.0
--| Created:  2007-10-08
--| Last Mod: --
--| Requires:  --
--|
--| Summary: Move progress thumb.
--|
--| Format:  doProgress param1, param2, param3, param4, param5
--|
--| Parameters: integer <pCurrNum>, integer <pProgressInterval>, string <pBarName>
--|             integer <pTotalNum>, bool <pEndPos>
--|
--| Return: empty
----------------------------------------------------------------------*/

command doProgress pCurrNum pProgressInterval pBarName pTotalNum pEndPos
   if sBusyCursor is TRUE then
      set cursor to busy
   end if

   if not pEndPos then
      set the thumbposition of scrollBar pBarName to pCurrNum
   else
      set the thumbposition of scrollBar pBarName to pTotalNum
      hideProgress pBarName -- temp test
      set cursor to arrow
   end if
end doProgress





command clearCurrentFileSize
   put empty into sCurrentFileSize
end clearCurrentFileSize




function commonSettings pCallback pOmitTsNet
   local tRequestDataA

   # COMMON
   put fld "hostFld" into tRequestDataA["host"]
   put fld "userFld" into tRequestDataA["username"]
   put fld "passwordFld" into tRequestDataA["password"]
   put the cAgent of this stack && the version && "(" & the platform &  ")" into tRequestDataA["user_agent"]

   if pOmitTsNet is TRUE then
      # NO tsNet
      put fld "portFld" into tRequestDataA["port"]
      put the label of btn "authBtn" into tRequestDataA["authType"]
      put the hilite of btn "secureBtn" into tRequestDataA["sslFlag"]

   else
      # tsNet
      put the label of btn "authBtn" into tAuthType
      if tAuthType is "Basic" then
         put TRUE into tRequestDataA["force_basic_auth"]
      else if tAuthType is "Digest" then
         put TRUE into tRequestDataA["force_digest_auth"]
      end if
      put TRUE into tRequestDataA["transfer_encoding"]

      put the hilite of btn "asynchronousBtn" into tRequestDataA["asynchronous"]
      put the hilite of btn "verifySSLPeerBtn" into tRequestDataA["verifySSLPeer"]

      put the hilite of btn "secureBtn" into tSSLflag
      put fld "davDirFld" into tRequestDataA["uri"]
      if tSSLflag is TRUE then
         put "https://" & tRequestDataA["host"] & tRequestDataA["uri"] into tRequestDataA["url"]
      else
         put "http://" & tRequestDataA["host"] & tRequestDataA["uri"] into tRequestDataA["url"]
      end if
   end if -- if pOmitTsNet is TRUE

   if pCallback is TRUE then
      put "urlCallback" into tCallBack
      put the long id of stack "webDavTest" into tCallbackTarget
      put tCallBack into tRequestDataA["callBack"]
      put tCallbackTarget into tRequestDataA["callbackTarget"]
   end if

   return tRequestDataA
end commonSettings





----------------------------------------------
# LOCAL FILES / FOLDERS
---------------------------------------------


-- file information Mac only
--
/*----------------------------------------------------------------------
--| FUNCTION fileInfoMac
--|
--| Author: --
--| Version:  1.1
--| Created:  2007-07-04
--| Last Mod: 2020-03-23
--| Requires:  --
--|
--| Summary:  File information, Mac only.
--|
--| Format:  fileInfoMac(param1,param2)
--|
--| Parameters: <pFile, pInfo>
--|
--| Return: mixed
----------------------------------------------------------------------*/

function fileInfoMac pFile,pInfo
   local tFolder, tFiles,tFilter, tSize, tDate, tType, tCreator
   -----
   set the itemdel to slash
   put item 1 to -2 of pFile into tFolder
   put URLDecode(files(tFolder, "detailed")) into tFiles

   filter tFiles with last item of pFile & "*"
   -----
   set the itemdel to comma
   switch pInfo
      case "size"
         put item 2 of tFiles + item 3 of tFiles into tSize
         put tSize div 1024 into tSize
         if tSize > 1000 then
            set the numberFormat to "0.0"
            put tSize / 1024 && "Mb" into tSize
         else put tSize && "Kb" into tSize
         return tSize
         break
      case "byteSize"
         put item 2 of tFiles + item 3 of tFiles into tSize
         return tSize
         break
      case "dataByteSize"
         put item 2 of tFiles into tSize
         return tSize
         break
      case "creation"
         put item 4 of tFiles into tDate
         convert tDate from seconds to system date and system time
         return tDate
         break
      case "modification"
         put item 5 of tFiles into tDate
         convert tDate from seconds to system date and system time
         return tDate
         break
      case "type"
         put char -4 to -1 of item 11 of tFiles into tType
         if tType = empty then return "????"
         else return tType
         break
      case "creator"
         put char -8 to -5 of item 11 of tFiles into tCreator
         if tCreator = empty then return "????"
         else return tCreator
   end switch
end fileInfoMac




/*----------------------------------------------------------------------
--| FUNCTION getFileSize
--|
--| Author: libURL
--| Version:  1.0
--| Created:  2008-05-01
--| Last Mod: --
--| Requires:  fileInfo
--|
--| Summary:  Get size of a given file.
--|
--| Format:  getFileSize(param1)
--|
--| Parameters: <pPath>
--|
--| Return: integer
----------------------------------------------------------------------*/

function getFileSize pPath
   put fileInfo(pPath) into tInfo
   return tInfo["fileSize"]
end getFileSize






/*----------------------------------------------------------------------
--| FUNCTION fileInfo
--|
--| Author: libURL
--| Version:  1.2
--| Created:  2008-05-01
--| Last Mod: 2020-03-23
--| Requires:  pathWithoutFileName, fileNameFromPath
--|
--| Summary:  Get all available information of a given file.
--|
--| Format:  fileInfo(param1)
--|
--| Parameters: string <pFileName>
--|
--| Return: array
----------------------------------------------------------------------*/

function fileInfo pFileName
   local tFolderName, tFileName, tInfo, tFileInfoA

   put pathWithoutFileName(pFileName) into tFolderName
   put fileNameFromPath(pFileName) into tFileName

   put URLDecode(files(tFolderName, "detailed")) into tFileList

   -- get lineoffset(tFileName,tFileList)
   -- put line it of tFileList into tInfo
   filter tFileList with tFileName & "*"
   put tFileList into tInfo

   put item 1 of tInfo into tFileInfoA["fileName"]
   put item 2 of tInfo into tFileInfoA["fileSize"]
   put item 3 of tInfo into tFileInfoA["resourceSize"]
   put item 4 of tInfo into tFileInfoA["created"]
   put item 5 of tInfo into tFileInfoA["lastModified"]
   put item 6 of tInfo into tFileInfoA["lastAccessed"]
   put item 7 of tInfo into tFileInfoA["lastBackedUp"]
   put item 8 of tInfo into tFileInfoA["Owner"]
   put item 9 of tInfo into tFileInfoA["GroupOwner"]
   put item 10 of tInfo into tFileInfoA["Permissions"]
   put item 11 of tInfo into tFileInfoA["fileType"]

   return tFileInfoA
end fileInfo





----------------------------------------------
# HANDLERS TO DISPLAY AN ARRAY IN READABLE FORM
---------------------------------------------

function printArray pArrayName, pArray
   if pArray is an array then
      put pArrayname & " = {" & "<br />" into tData
      put dumpArray(pArray, " ", " ") after tData
      put "}" after tData
   end if

   return tData
end printArray



function dumpArray pArray, pIndent, pIndentString
   if pArray is an array then
      put the keys of pArray into tKeys
      sort lines of tKeys
      repeat for each line tKey in tKeys
         if pArray[tKey] is an array then
            put pIndent & tKey & " = {" & "<br />" & return after tArrayData
            put dumpArray(pArray[tKey], (pIndent & pIndentString), pIndentString) after tArrayData
            put pIndent & "}" & "<br />" & return after tArrayData
         else
            put pIndent & tKey & " = " & pArray[tKey] & "<br />" & return after tArrayData
         end if
      end repeat

      return tArrayData
   end if

   return FALSE
end dumpArray





----------------------------------
# XML HANDLERS (by Trevor DeVore)
----------------------------------

-- Following handlers provided by Trevor DeVore of Blue Mango Learning Systems.
--
-- Converts an XML tree into a LiveCode multi-dimensional array.
-- A nodes attributes will be stored as an array of it's "@attributes" key.
-- Node names will retain the sequence information (i.e. node[1], node[2], etc.).
-- This information is necessary to determine order that keys should be processed in. Example:
-- set the itemDelimiter to "["
-- put the keys of theArray into theKeys
-- sort theKeys numeric by the last item of each
--
-- pUseValueKey: The default value is false. In this case you get an array that has an @attributes
-- key for nodes that have attributes and either a) no value or b) only child nodes. Otherwise it contains the node contents.
-- Set to true if you want to store a nodes value in the '@value' key. This will allow a key to have
-- both attributes (in @attributes key) and a value (in @value key).
--
function convertXMLToArray pXML, pStoreEncodedAs, pUseValueKey
   local theArray,theResult,theRootNode,theTreeID
   local theXMLEncoding

   ## Create an XML tree from XML text
   put revCreateXMLTree(pXML, true, true, false) into theTreeID

   if theTreeID is an integer then
      ## Determine the encoding of the XML, default to UTF-8
      put matchtext(pXML, "<\?xml (.*)encoding=" & quote & "(.*)" & quote & "\?>", versionMatch, theXMLEncoding) into theResult
      if theXMLEncoding is empty then put "utf-8" into theXMLEncoding

      ## Now convert to array.
      ## The 1st dimension has one key which is the name of the root node.
      put revXMLRootNode(theTreeID) into theRootNode
      if theRootNode is not empty and not(theRootNode begins with "xmlerr,") then
         put ConvertXMLNodeToArray(theTreeID, theRootNode, theXMLEncoding, pStoreEncodedAs, pUseValueKey) into theArray[theRootNode]
      end if
   end if

   return theArray
end convertXMLToArray




function ConvertXMLTreeToArray pXMLTree, pStoreEncodedAs, pUseValueKey
   return ConvertXMLToArray(revXMLText(pXMLTree), pStoreEncodedAs, pUseValueKey)
end ConvertXMLTreeToArray


--
-- Converts a multi-dimensional array to an XML tree.
-- The array should contain one key in the 1st dimension which
-- will become the root node. Attributes of a node should be stored
-- as an array in the @attributes key. Sequence information for multiple
-- nodes with the same name should be included in the node name using
-- brackets (i.e. node[1], node[2], node[3]).
-- Returns an xml tree id (integer) or an error message.
--
function ConvertArrayToXML pArray, pArrayEncoding, pStoreEncodedAs
   local theError,theRootNode,theXML,theXMLTree

   ## if pArrayEncoding is empty then current platform encoding is assumed
   if pStoreEncodedAs is empty then put "UTF-8" into pStoreEncodedAs

   ## Create XML for root node. Note that we take extra steps in order to support
   ## converting an array that only represents part of a tree rather than the entire tree.
   ## In this case there may be multiple nodes at the root level.
   put line 1 of the keys of pArray into theRootNode
   set the itemdelimiter to "["
   put "<" & item 1 of theRootNode & "/>" into theXML

   ## Create XML needed to create tree
   put format("<?xml version=\"1.0\" encoding=\"%s\"?>%s", \
           pStoreEncodedAs, theXML) into theXML
   put revCreateXMLTree(theXML, true, true, false) into theXMLTree

   if theXMLTree is an integer then
       ## Loop over all nodes at root level
       put SortArrayKeysWithXMLOrdering(pArray) into theNodes

       ## Create tree using helper function
       repeat for each line theNode in theNodes
           ConvertArrayDimensionToXML pArray[theNode], theXMLTree, slash & theNode, \
                   pArrayEncoding, pStoreEncodedAs
           put the result into theError

           if theError is not empty then exit repeat
       end repeat

       if theError is not empty then
           ## something went wrong, clean bad tree
           revDeleteXMLTree theXMLTree
       end if
   else
       put theXMLTree into theError
   end if

   if theError is not empty then
       return theError
   else
       return theXMLTree
   end if
end ConvertArrayToXML

--
-- Helper function for ConvertArrayToXML
-- Converts the multi-dimensional array pArray to nodes in pTreeID.-- Calls itself recursively.
-- Returns error message.
--
private command ConvertArrayDimensionToXML pArray, pTreeID, pNode, pArrayEncoding, pStoreEncodedAs
   local theError,theKey,theKeys,theNode

   ## A workaround for fact that LiveCode does not return
   ## keys in the order we created them
   put SortArrayKeysWithXMLOrdering(pArray) into theNodes

   ## Arrays might have sequencing info in name
   ## (i.e. step[1], step[2], ... )
   set the itemdelimiter to "["

   repeat for each line theFullNode in theNodes
      put item 1 of theFullNode into theNode

      ## Look for attributes. These will be added as attributes to pNode.
      if theNode is "@attributes" then
         repeat for each line theKey in the keys of pArray[theFullNode]
            revSetXMLAttribute pTreeID, pNode, theKey, \
                  EncodeString(pArray[theFullNode][theKey], \
                  pArrayEncoding, pStoreEncodedAs)
            if the result begins with "xmlerr," then
               put the result && "(setting attribute" && theKey && "for node" && pNode & ")" into theError
            end if

            if theError is not empty then exit repeat
         end repeat

      else if theNode is "@value" then
         ## This XML tree is using complex structure. Node is the value of the parent node
         revPutIntoXMLNode pTreeID, pNode, EncodeString(pArray[theFullNode], pArrayEncoding, pStoreEncodedAs)
         if the result begins with "xmlerr," then
            put the result && "(adding child node" && theNode && "to node" && pNode & ")" into theError
         end if

      else
         if the keys of pArray[theFullNode] is not empty then
            ## Node has children. Add node to XML tree then call self recursivly to create children nodes.
            revAddXMLNode pTreeID, pNode, theNode, empty
            if the result begins with "xmlerr," then
               put the result && "(adding node" && theNode & ")" into theError
            end if

            if theError is empty then
               ConvertArrayDimensionToXML pArray[theFullNode], pTreeID, pNode & slash & theFullNode, \
                     pArrayEncoding, pStoreEncodedAs
               put the result into theError
            end if
         else
            ## Node has no children but possibly a value. Create node and add value (which may be empty).
            revAddXMLNode pTreeID, pNode, theNode, \
                  EncodeString(pArray[theFullNode], pArrayEncoding, pStoreEncodedAs)
            if the result begins with "xmlerr," then
               put the result && "(adding child node" && theNode && "to node" && pNode & ")" into theError
            end if
         end if
      end if

      if theError is not empty then exit repeat
   end repeat

   return theError
end ConvertArrayDimensionToXML


--
-- LiveCode array keys are never guaranteed to be in order you created
-- them in so we must come up with some other way of maintaining
-- proper sequence. For arrays representing XML, the XML syntax is
-- used (i.e. node[1], node[2], etc.). This handler will sort keys that use
-- this syntax for representing sequence.
--
function SortArrayKeysWithXMLOrdering pArray
   put the keys of pArray into theKeys
   set the itemdelimiter to "["
   sort theKeys numeric by the last item of each -- 1], 2], 3], etc.

   set the wholematches to true
   put lineoffset("@attributes", theKeys) into theLineNo
   if theLineNo > 0 then
       delete line theLineNo of theKeys
   end if

   return theKeys
end SortArrayKeysWithXMLOrdering


--
-- Helper function for ConvertXMLToArray.
-- Converts an XML node to a multi-dimensional array.-- Calls itself recursively.
--
private function ConvertXMLNodeToArray pTreeID, pNode, pXMLTreeEncoding, pStoreEncodedAs, pUseValueKey
   local theArrayA,theAttributes,theChildNode,theKey

   ## Look for attributes of the node. Store as array in "@attributes" key
   put revXMLAttributes(pTreeID, pNode, tab, cr) into theAttributes
   if theAttributes is not empty then
       put EncodeString(theAttributes, pXMLTreeEncoding, pStoreEncodedAs) into theAttributes
       split theAttributes by cr and tab -- create array
       put theAttributes into theArrayA["@attributes"]
   end if

   ## Look for children nodes.
   set the itemdelimiter to slash
   put revXMLFirstChild(pTreeID, pNode) into theChildNode
   if theChildNode is empty or theChildNode begins with "xmlerr," then
       put EncodeString(revXMLNodeContents(pTreeID, pNode), pXMLTreeEncoding, pStoreEncodedAs) into theValue
       if word 1 to -1 of theValue is empty and the keys of theArrayA is not empty then
           ## Empty node that has attributes
           return theArrayA
       else if pUseValueKey then
           ## Force value into @value
           put theValue into theArrayA["@value"]
           return theArrayA
       else
           ## Single Node with value: Return value. Attributes are ignored.
           return theValue
       end if
   else
       ## Child nodes were found. Recursively call self and store result in array.
       repeat while theChildNode is not empty and not (theChildNode begins with "xmlerr,")
           put the last item of theChildNode into theKey
           put ConvertXMLNodeToArray(pTreeID, theChildNode, pXMLTreeEncoding, pStoreEncodedAs, pUseValueKey) into theArrayA[theKey]
           put revXMLNextSibling(pTreeID, theChildNode) into theChildNode
       end repeat

       return theArrayA
   end if
end ConvertXMLNodeToArray

--
-- Helper function for converting the encoding of strings when converting to and from XML.
--
private function EncodeString pString, pInEncoding, pOutEncoding
   ## convert utf-8 to utf8 for uniencode/decode
   replace "-" with empty in pInEncoding
   replace "-" with empty in pOutEncoding

   if pInEncoding is not empty then
      -- if pOutEncoding is empty then pString will be converted to the current platform encoding
      return unidecode(uniencode(pString, pInEncoding), pOutEncoding)
   else
      if pOutEncoding is not empty then
         -- if pInEncoding is empty then pString is assumed to be in the current platform encoding
         return unidecode(uniencode(pString, pInEncoding), pOutEncoding)
      else
         return pString
      end if
   end if
end EncodeString
