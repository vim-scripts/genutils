"
" Useful buffer, file and window related functions.
"
" Author: Hari <hari_vim@yahoo.com>
" Last Modified: 04-Feb-2002 @ 18:49
" Requires: Vim-6.0, multvals.vim(2.0.5)
" Version: 1.0.8
"

"
" Return the number of windows open currently.
"
function! NumberOfWindows()
  let i = 1
  while winbufnr(i) != -1
    let i = i+1
  endwhile
  return i - 1
endfunction

"
" Find the window number for the buffer passed.
"
function! FindWindowForBuffer(bufferName, checkUnlisted)
  let bufno = bufnr(a:bufferName)
  " bufnr() will not find unlisted buffers.
  if bufno == -1 && a:checkUnlisted
    " Iterate over all the open windows for 
    let i = 1
    while winbufnr(i) != -1
      if bufname(winbufnr(i)) == a:bufferName
        return i;
      endif
      let i = i + 1
    endwhile
  endif
  return bufwinnr(bufno)
endfunction

" Returns the buffer number of the given fileName if it is already loaded.
" Works around the bug in bufnr().
function! FindBufferForName(fileName)
  let i = bufnr(a:fileName)
  if i != -1
    return i
  endif

  " If bufnr didn't work, the it probably is a hidden buffer, so check the
  "   hidden buffers.
  let i = 1
  while i <= bufnr("$")
    if bufexists(i) && ! buflisted(i) && (match(bufname(i), a:fileName) != -1)
      break
    endif
    let i = i + 1
  endwhile
  if i <= bufnr("$")
    return i
  else
    return -1
  endif
endfunction


" Given the window number, moves the cursor to that window.
function! MoveCursorToWindow(winno)
  if NumberOfWindows() != 1
    execute a:winno . " wincmd w"
  endif
endfunction


" Moves the current line such that it is going to be the nth line in the window
"   without changing the column position.
function! MoveCurLineToWinLine(n)
  normal zt
  execute "normal " . a:n . "\<C-Y>"
endfunction


"
" Saves the heights of the currently open windows for restoring later.
"
function! SaveWindowSettings()
  let s:savedWindowSettings = ""
  let s:savedWindowSettings = MvAddElement(s:savedWindowSettings, ",",
          \ NumberOfWindows())
  let s:savedWindowSettings = MvAddElement(s:savedWindowSettings, ",", &lines)
  let s:savedWindowSettings = MvAddElement(s:savedWindowSettings, ",", &columns)
  let s:savedWindowSettings = MvAddElement(s:savedWindowSettings, ",", winnr())
  let i = 1
  while winbufnr(i) != -1
    let s:savedWindowSettings = MvAddElement(s:savedWindowSettings, ",",
            \ winheight(i))
    let s:savedWindowSettings = MvAddElement(s:savedWindowSettings, ",",
            \ winwidth(i))
    let i = i + 1
  endwhile
  "let g:savedWindowSettings = s:savedWindowSettings " Debug.
endfunction

"
" Restores the heights of the windows from the information that is saved by
"  SaveWindowSettings().
"
function! RestoreWindowSettings()
  if ! exists("s:savedWindowSettings")
    return
  endif

  call MvIterCreate(s:savedWindowSettings, ",", "savedWindowSettings")
  let nWindows = MvIterNext("savedWindowSettings")
  if nWindows != NumberOfWindows()
    unlet s:savedWindowSettings
    call MvIterDestroy("savedWindowSettings")
    return
  endif
  let orgLines = MvIterNext("savedWindowSettings")
  let orgCols = MvIterNext("savedWindowSettings")
  let activeWindow = MvIterNext("savedWindowSettings")
  
  let winNo = 1
  while MvIterHasNext("savedWindowSettings")
    let height = MvIterNext("savedWindowSettings")
    let width = MvIterNext("savedWindowSettings")
    call MoveCursorToWindow(winNo)
    exec 'resize ' . ((&lines * height + (orgLines / 2)) / orgLines)
    exec 'vert resize ' . ((&columns * width + (orgCols / 2)) / orgCols)
    let winNo = winNo + 1
  endwhile
  
  " Restore the current window.
  call MoveCursorToWindow(activeWindow)
  call ResetWindowSettings()
  "unlet g:savedWindowSettings " Debug.
  call MvIterDestroy("savedWindowSettings")
endfunction


function! ResetWindowSettings()
  if exists("s:savedWindowSettings")
    unlet s:savedWindowSettings
  endif
endfunction


" Cleanup file name such that two *cleaned up* file names are easy to be
"   compared.
function! CleanupFileName(file)
  let fileName=a:file
  " Remove multiple path separators.
  if has("win32")
    let fileName=substitute(fileName, "\\", "/", "g")
  elseif has("win16") || has("dos16") || has("dos32")
    let fileName=substitute(fileName, "\\\\{2,}", "\\", "g")
  endif
  let fileName=substitute(fileName, "/\\{2,}", "/", "g")

  " Remove ending extra path separators.
  let fileName=substitute(fileName, "/$", "", "")
  let fileName=substitute(fileName, "\\$", "", "")

  if has("win32") || has("dos32") || has("win16") || has("dos16")
    let fileName=substitute(fileName, "^[A-Z]:", "\\L&", "")
  endif
  return fileName
endfunction

function! PathIsAbsolute(path)
  let absolute=0
  if has("unix") || has("win32")
    if match(a:path, "/") == 0
      let absolute=1
    endif
  endif
  if (! absolute) && has("win32")
    if match(a:path, "\\") == 0
      let absolute=1
    endif
  endif
  if (! absolute) && (has("win32") || has("dos32") || has("win16") || has("dos16"))
    if match(a:path, "^[A-Za-z]:") == 0
      let absolute=1
    endif
  endif
  return absolute
endfunction

function! PathIsFileNameOnly(path)
  return (match(a:path, "\\") < 0) && (match(a:path, "/") < 0)
endfunction

" Copy this method into your script and rename it to find the script id of the
"   current script.
function! SampleScriptIdFunction()
  map <SID>xx <SID>xx
  let s:sid = maparg("<SID>xx")
  unmap <SID>xx
  return substitute(s:sid, "xx$", "", "")
endfunction


""
"" --- START save/restore position.
""

" characters that must be escaped for a regular expression
let s:escregexp = '/*^$.~\'


" This method tries to save the position along with the line context if
"   possible. This is like the vim builtin marker. Pass in a unique scriptid.
function! SaveSoftPosition(scriptid)
  let s:startline_{a:scriptid} = getline(".")
  call SaveHardPosition(a:scriptid)
endfunction


function! RestoreSoftPosition(scriptid)
  0
  if search('\m^'.escape(s:startline_{a:scriptid},s:escregexp),'W') <= 0
    call RestoreHardPosition(a:scriptid)
  else
    execute "normal!" s:col_{a:scriptid} . "|"
    call MoveCurLineToWinLine(s:winline_{a:scriptid})
  endif
endfunction


function! ResetSoftPosition(scriptid)
  unlet s:startline_{a:scriptid}
endfunction


" A synonym for SaveSoftPosition.
function! SaveHardPositionWithContext(scriptid)
  call SaveSoftPosition(a:scriptid)
endfunction


" A synonym for RestoreSoftPosition.
function! RestoreHardPositionWithContext(scriptid)
  call RestoreSoftPosition(a:scriptid)
endfunction


" A synonym for ResetSoftPosition.
function! ResetHardPositionWithContext(scriptid)
  call ResetSoftPosition(a:scriptid)
endfunction


" Useful when you want to go to the exact (line, col), but marking will not
"   work, or if you simply don't want to disturb the marks. Pass in a unique
"   scriptid.
function! SaveHardPosition(scriptid)
  let s:col_{a:scriptid} = virtcol(".")
  let s:lin_{a:scriptid} = line(".")
  let s:winline_{a:scriptid} = winline()
endfunction


function! RestoreHardPosition(scriptid)
  execute s:lin_{a:scriptid}
  execute "normal!" s:col_{a:scriptid} . "|"
  call MoveCurLineToWinLine(s:winline_{a:scriptid})
endfunction


function! ResetHardPosition(scriptid)
  unlet s:col_{a:scriptid}
  unlet s:lin_{a:scriptid}
  unlet s:winline_{a:scriptid}
endfunction

""
"" --- END save/restore position.
""



""
"" --- START: Notify window close --
""


"
" When the window with the title windowTitle is closed, the global function
"   functionName is called with the title as an argument, and the entries are
"   removed, so if you are still interested, you need to register again.
"
function! AddNotifyWindowClose(windowTitle, functionName)
  " Make sure there is only one entry per window title.
  if exists("s:notifyWindowTitles") && s:notifyWindowTitles != ""
    call RemoveNotifyWindowClose(a:windowTitle)
  endif

  if !exists("s:notifyWindowTitles")
    " Both separated by :.
    let s:notifyWindowTitles = ""
    let s:notifyWindowFunctions = ""
  endif

  let s:notifyWindowTitles = MvAddElement(s:notifyWindowTitles, ":",
          \ a:windowTitle)
  let s:notifyWindowFunctions = MvAddElement(s:notifyWindowFunctions, ":",
          \ a:functionName)

  let g:notifyWindowTitles = s:notifyWindowTitles " Debug.
  let g:notifyWindowFunctions = s:notifyWindowFunctions " Debug.

  " Start listening to events.
  aug NotifyWindowClose
    au!
    au WinEnter * :call CheckWindowClose()
  aug END
endfunction


function! RemoveNotifyWindowClose(windowTitle)
  if MvContainsElement(s:notifyWindowTitles, ":", a:windowTitle)
    let index = MvIndexOfElement(s:notifyWindowTitles, ":", a:windowTitle)
    let s:notifyWindowTitles = MvRemoveElementAt(s:notifyWindowTitles, ":",
            \ index)
    let s:notifyWindowFunctions = MvRemoveElementAt(s:notifyWindowFunctions,
            \ ":", index)

    if s:notifyWindowTitles == ""
      unlet s:notifyWindowTitles
      unlet s:notifyWindowFunctions
      unlet g:notifyWindowTitles " Debug.
      unlet g:notifyWindowFunctions " Debug.
  
      aug NotifyWindowClose
        au!
      aug END
    endif
  endif
endfunction


function! CheckWindowClose()
  " First make an array with all the existing window titles.
  let i = 1
  let currentWindows = ""
  while winbufnr(i) != -1
    let bufname = bufname(winbufnr(i))
    if bufname != ""
      let currentWindows = MvAddElement(currentWindows, ":", bufname)
    endif
    let i = i+1
  endwhile
  "call input("currentWindows: " . currentWindows)

  " Now iterate over all the registered window titles and see which one's are
  "   closed.
  let i = 0 " To track the element index.
  " Take a copy and modify these if needed, as we are not supposed to modify
  "   the main arrays while iterating over them.
  let processedElements = ""
  call MvIterCreate(s:notifyWindowTitles, ":", "NotifyWindowClose")
  while MvIterHasNext("NotifyWindowClose")
    let nextWin = MvIterNext("NotifyWindowClose")
    if ! MvContainsElement(currentWindows, ":", nextWin)
      let funcName = MvElementAt(s:notifyWindowFunctions, ":", i)
      let cmd = "call " . funcName . "(\"" . nextWin . "\")"
      "call input("cmd: " . cmd)
      exec cmd

      " Remove these entries as these are already processed.
      let processedElements = MvAddElement(processedElements, ":", nextWin)
    endif
  endwhile
  call MvIterDestroy("NotifyWindowClose")

  call MvIterCreate(processedElements, ":", "NotifyWindowClose")
  while MvIterHasNext("NotifyWindowClose")
    let nextWin = MvIterNext("NotifyWindowClose")
    call RemoveNotifyWindowClose(nextWin)
  endwhile
  call MvIterDestroy("NotifyWindowClose")
endfunction


"function! NotifyWindowCloseF(title)
"  call input(a:title . " closed")
"endfunction
"
"function! RunNotifyWindowCloseTest()
"  split ABC
"  split XYZ
"  call AddNotifyWindowClose("ABC", "NotifyWindowCloseF")
"  call AddNotifyWindowClose("XYZ", "NotifyWindowCloseF")
"  call input("notifyWindowTitles: " . s:notifyWindowTitles)
"  call input("notifyWindowFunctions: " . s:notifyWindowFunctions)
"  au WinEnter
"  split b
"  call input("Starting the tests:")
"  quit
"  quit
"  quit
"endfunction


""
"" --- END: Notify window close --
""



"
" TODO: For large ranges, the cmd can become too big, so make it one cmd per
"         line.
" Originally,
" From: Gary Holloway <gary@castandcrew.com>
" Date: Wed, 16 Jan 2002 14:31:56 -0800
"
" Display the given line(s) from the current file in the command area (i.e.,
" echo), using that line's syntax highlighting (i.e., WYSIWYG).
"
" If no line number is given, display the current line.
"
function! ShowLinesWithSyntax() range
  " This makes sure we start (subsequent) echo's on the first line in the
  " command-line area.
  "
  echo ''

  let cmd        = ''
  let prev_group = ' x '     " Something that won't match any syntax group.

  let show_line = a:firstline
  let isMultiLine = ((a:lastline - a:firstline) > 1)
  while show_line <= a:lastline
    if (show_line - a:firstline) > 1
      let cmd = cmd . '\n'
    endif

    let length = strlen(getline(show_line))
    let column = 1

    while column <= length
      let group = synIDattr(synID(show_line, column, 1), 'name')
      if group != prev_group
        if cmd != ''
          let cmd = cmd . '"|'
        endif
        let cmd = cmd . 'echohl ' . (group == '' ? 'NONE' : group) . '|echon "'
        let prev_group = group
      endif
      let char = strpart(getline(show_line), column - 1, 1)
      if char == '"'
        let char = '\"'
      endif
      let cmd = cmd . char
      let column = column + 1
    endwhile

    let show_line = show_line + 1
  endwhile
  let cmd = cmd . '"|echohl NONE'

  let g:firstone = cmd
  exe cmd
endfunction
