"
" Useful buffer, file and window related functions.
"
" Author: Hari Krishna Dara <hari_vim@yahoo.com>
" Last Modified: 25-Mar-2002 @ 10:36
" Requires: Vim-6.0, multvals.vim(2.0.5)
" Version: 1.0.19
" Description:
"   - A scriptlet to pass variable number of arguments to other functions.
"   - Misc. window/buffer related functions, NumberOfWindows(),
"     FindWindowForBuffer(), FindBufferForName(), MoveCursorToWindow(),
"     MoveCurLineToWinLine(), SetupScratchBuffer(), MapAppendCascaded()
"   - Save/Restore all the window height/width settings to be restored later.
"   - Save/Restore position in the buffer to be restored later. Works like the
"     built-in marks feature, but has more to it.
"   - NotifyWindowClose() to get notifications *after* a window with the
"     specified buffer has been closed or the buffer is unloaded. The built-in
"     autocommands can only notify you *before* the window is closed. You can
"     use this with the Save/Restore window settings feature to restore the
"     user windows, after your window is closed. I have used this utility in
"     selectbuf.vim to restore window dimensions after the browser window is
"     closed. To add your function to be notified when a window is closed, use
"     the function:
"
"         function! AddNotifyWindowClose(windowTitle, functionName)
"
"     There is also a test function called RunNotifyWindowCloseTest() that
"     demos the usage.
"   - ShowLinesWithSyntax() function to echo lines with syntax coloring.
"   - ShiftWordInSpace() a small utility function to move words in the
"     space without changing the width of the field.
"   - A quick-sort function that can sort a buffer contents by range. Adds
"     utility commands SortByLength and RSortByLength to sort contents by line
"     length.
"   - A sample function to extract the scriptId of a script.
"
"   - Place the following  in your vimrc if you find them useful:
"
"       command! DiffOff :call CleanDiffOptions()
"       
"       command! -nargs=0 -range=% SortByLength <line1>,<line2>call QSort(
"           \ 's:CmpByLineLength', 1)
"       command! -nargs=0 -range=% RSortByLength <line1>,<line2>call QSort(
"           \ 's:CmpByLineLength', -1)
"
"	nnoremap <silent> \ :call ExecMap('\')<CR>
"

if exists("loaded_genutils")
  finish
endif
let loaded_genutils = 1

" Execute this following variable in your function to make a string containing
"   all your arguments. The string can be used to pass the variable number of
"   arguments received by your script further down into other functions.
" Ex:
"   fu! s:IF(...)
"     exec g:makeArgumentString
"     exec "call Impl(" . argumentString . ")"
"   endfu
let makeArgumentString = "
    \   if (exists('argCounter'))\n
    \    let __argCounter = argCounter\n
    \  endif \n
    \  if (exists('nextArgument'))\n
    \    let __nextArg = nextArgument\n
    \  endif\n
    \  let argCounter = 1\n
    \  let argumentString = ''\n
    \  while argCounter <= a:0\n
    \    let nextArgument = substitute(a:{argCounter},
             \ \"'\", \"' . \\\"'\\\" . '\", \"g\")\n
    \    let argumentString = argumentString . \"'\" . nextArgument . \"'\" .
             \ ((argCounter == a:0) ? '' : ', ')\n
    \    let argCounter = argCounter + 1\n
    \  endwhile \n
    \  if (exists('__argCounter'))\n
    \    let argCounter = __argCounter\n
    \    unlet __argCounter\n
    \  endif \n
    \  if (exists('__nextArg'))\n
    \    let nextArgument = __nextArg\n
    \    unlet __nextArg\n
    \  endif\n
    \ "

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
" Find the window number for the buffer passed. If checkUnlisted is non-zero,
"   then it searches for the buffer in the unlisted buffers, to work-around
"   the vim bug that bufnr() doesn't work for unlisted buffers. It also
"   unprotects any extra back-slashes from the bufferName, for the sake of
"   comparision with the existing buffer names.
"
function! FindWindowForBuffer(bufferName, checkUnlisted)
  let bufno = bufnr(a:bufferName)
  " bufnr() will not find unlisted buffers.
  if bufno == -1 && a:checkUnlisted
    " Iterate over all the open windows for 

    " The window name could be having extra backslashes to protect certain
    " chars, so first expand them.
    exec "let bufName = \"" . a:bufferName . "\"" 
    let i = 1
    while winbufnr(i) != -1
      if bufname(winbufnr(i)) == bufName
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


" Turn on some buffer settings that make it suitable to be a scratch buffer.
function! SetupScratchBuffer()
  setlocal noswapfile
  setlocal nobuflisted
  setlocal buftype=nofile
  " Just in case, this will make sure we are always hidden.
  setlocal bufhidden=delete
endfunction


" Turns off those options that are set by diff to the current window.
"   Also removes the 'hor' option from scrollopt (which is a global option).
" Better alternative would be to close the window and reopen the buffer in a
"   new window. 
function! CleanDiffOptions()
  setlocal nodiff
  setlocal noscrollbind
  setlocal scrollopt-=hor
  setlocal wrap
  setlocal foldmethod=manual
  setlocal foldcolumn=0
endfunction


" This function is an alternative to exists() function, for those odd array
"   index names for which the built-in function fails. The var should be
"   accessible to this functions, so it should be a global variable.
"     if ArrayVarExists("array", id)
"       let val = array{id}
"     endif
function! ArrayVarExists(varName, index)
  let v:errmsg = ""
  silent! exec "let test = " . a:varName . "{a:index}"
  if !exists("test") || test == ""
    return 0
  endif
  return 1
endfunction


" Returns 1 if preview window is open or 0 if not.
function! IsPreviewWindowOpen()
  let v:errmsg = ""
  silent! exec "wincmd P"
  if v:errmsg != ""
    return 0
  else
    wincmd p
    return 1
  endif
endfunction


"
" Saves the heights and widths of the currently open windows for restoring
"   later.
"
function! SaveWindowSettings()
  call SaveWindowSettings2(s:myScriptId, 1)
endfunction


"
" Restores the heights of the windows from the information that is saved by
"  SaveWindowSettings().
"
function! RestoreWindowSettings()
  call RestoreWindowSettings2(s:myScriptId)
endfunction


function! ResetWindowSettings()
  call RestoreWindowSettings2(s:myScriptId)
endfunction


" Same as SaveWindowSettings, but uses the passed in scriptid to create a
"   private copy for the calling script. Pass in a unique scriptid to avoid
"   conflicting with other callers. If overwrite is zero and if the settings
"   are already stored for the passed in sid, it will overwriting previously
"   saved settings.
function! SaveWindowSettings2(sid, overwrite)
  if ArrayVarExists("s:winSettings", a:sid) && ! a:overwrite
    return
  endif

  let s:winSettings{a:sid} = ""
  let s:winSettings{a:sid} = MvAddElement(s:winSettings{a:sid}, ",",
          \ NumberOfWindows())
  let s:winSettings{a:sid} = MvAddElement(s:winSettings{a:sid}, ",", &lines)
  let s:winSettings{a:sid} = MvAddElement(s:winSettings{a:sid}, ",", &columns)
  let s:winSettings{a:sid} = MvAddElement(s:winSettings{a:sid}, ",", winnr())
  let i = 1
  while winbufnr(i) != -1
    let s:winSettings{a:sid} = MvAddElement(s:winSettings{a:sid}, ",",
            \ winheight(i))
    let s:winSettings{a:sid} = MvAddElement(s:winSettings{a:sid}, ",",
            \ winwidth(i))
    let i = i + 1
  endwhile
  "let g:savedWindowSettings = s:winSettings{a:sid} " Debug.
endfunction


" Same as RestoreWindowSettings, but uses the passed in scriptid to get the
"   settings.
function! RestoreWindowSettings2(sid)
  "if ! exists("s:winSettings" . a:sid)
  if ! ArrayVarExists("s:winSettings", a:sid)
    return
  endif

  call MvIterCreate(s:winSettings{a:sid}, ",", "savedWindowSettings")
  let nWindows = MvIterNext("savedWindowSettings")
  if nWindows != NumberOfWindows()
    unlet s:winSettings{a:sid}
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


function! ResetWindowSettings2(sid)
  if ! ArrayVarExists("s:winSettings", a:sid)
    unlet s:winSettings{a:sid}
  endif
endfunction


" Cleanup file name such that two *cleaned up* file names are easy to be
"   compared.
function! CleanupFileName(file)
  let fileName = a:file
  " Remove multiple path separators.
  if has("win32")
    let fileName=substitute(fileName, "\\", "/", "g")
  elseif OnMS()
    let fileName=substitute(fileName, "\\\\{2,}", "\\", "g")
  endif
  let fileName=substitute(fileName, "/\\{2,}", "/", "g")

  " Remove ending extra path separators.
  let fileName=substitute(fileName, "/$", "", "")
  let fileName=substitute(fileName, "\\$", "", "")

  if OnMS()
    let fileName=substitute(fileName, "^[A-Z]:", "\\L&", "")
  endif
  return fileName
endfunction


function! OnMS()
  return has("win32") || has("dos32") || has("win16") || has("dos16") ||
       \ has("win95")
endfunction


function! PathIsAbsolute(path)
  let absolute=0
  if has("unix") || OnMS()
    if match(a:path, "^/") == 0
      let absolute=1
    endif
  endif
  if (! absolute) && OnMS()
    if match(a:path, "^\\") == 0
      let absolute=1
    endif
  endif
  if (! absolute) && OnMS()
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
let s:myScriptId = SampleScriptIdFunction()


""
"" --- START save/restore position.
""

" characters that must be escaped for a regular expression
let s:escregexp = '/*^$.~\'


" This method tries to save the position along with the line context if
"   possible. This is like the vim builtin marker. Pass in a unique scriptid
"   to avoid conflicting with other callers.
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
  " The window name could be having extra backslashes to protect certain
  " chars, so first expand them.
  exec "let bufName = \"" . a:windowTitle . "\"" 

  " Make sure there is only one entry per window title.
  if exists("s:notifyWindowTitles") && s:notifyWindowTitles != ""
    call RemoveNotifyWindowClose(bufName)
  endif

  if !exists("s:notifyWindowTitles")
    " Both separated by :.
    let s:notifyWindowTitles = ""
    let s:notifyWindowFunctions = ""
  endif

  let s:notifyWindowTitles = MvAddElement(s:notifyWindowTitles, ";", bufName)
  let s:notifyWindowFunctions = MvAddElement(s:notifyWindowFunctions, ";",
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
  " The window name could be having extra backslashes to protect certain
  " chars, so first expand them.
  exec "let bufName = \"" . a:windowTitle . "\"" 

  if !exists("s:notifyWindowTitles")
    return
  endif

  if MvContainsElement(s:notifyWindowTitles, ";", bufName)
    let index = MvIndexOfElement(s:notifyWindowTitles, ";", bufName)
    let s:notifyWindowTitles = MvRemoveElementAt(s:notifyWindowTitles, ";",
            \ index)
    let s:notifyWindowFunctions = MvRemoveElementAt(s:notifyWindowFunctions,
            \ ";", index)

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
  if !exists("s:notifyWindowTitles")
    return
  endif

  " First make an array with all the existing window titles.
  let i = 1
  let currentWindows = ""
  while winbufnr(i) != -1
    let bufname = bufname(winbufnr(i))
    if bufname != ""
      let currentWindows = MvAddElement(currentWindows, ";", bufname)
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
  call MvIterCreate(s:notifyWindowTitles, ";", "NotifyWindowClose")
  while MvIterHasNext("NotifyWindowClose")
    let nextWin = MvIterNext("NotifyWindowClose")
    if ! MvContainsElement(currentWindows, ";", nextWin)
      let funcName = MvElementAt(s:notifyWindowFunctions, ";", i)
      let cmd = "call " . funcName . "(\"" . nextWin . "\")"
      "call input("cmd: " . cmd)
      exec cmd

      " Remove these entries as these are already processed.
      let processedElements = MvAddElement(processedElements, ";", nextWin)
    endif
  endwhile
  call MvIterDestroy("NotifyWindowClose")

  call MvIterCreate(processedElements, ";", "NotifyWindowClose")
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
"  call input("Starting the tests, you should see two notifications:")
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
" Display the given line(s) from the current file in the command area (i.e.,
" echo), using that line's syntax highlighting (i.e., WYSIWYG).
"
" If no line number is given, display the current line.
"
" Originally,
" From: Gary Holloway <gary@castandcrew.com>
" Date: Wed, 16 Jan 2002 14:31:56 -0800
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


" This function shifts the word in the space without moving the following words.
"   Doesn't work for tabs.
function! ShiftWordInSpace(dir)
  let moveToWordStart = '"_yiw'
  if a:dir == 1 " forward.
    " If currently on <Space>...
    if getline(".")[col(".") - 1] == " "
      let moveCommand = 'e'
    else
      let moveCommand = moveToWordStart . 'e'
    endif
    let removeCommand = "lx"
    let pasteCommand = moveToWordStart . "i "
    let offset = 1
  else " backward.
    " If currently on <Space>...
    if getline(".")[col(".") - 1] == " "
      let moveCommand = 'w'
    else
      let moveCommand = moveToWordStart
    endif
    let removeCommand = "hx"
    let pasteCommand = moveToWordStart . "ea "
    let offset = -3
  endif

  " Check if there is a space at the end.
  exec "normal" moveCommand
  let savedCol = col(".")
  let curCol = col(".")
  let possible = 0
  if col("$") == (curCol + 1) " Works only for forward case, as expected.
    let possible = 1
  elseif getline(".")[curCol + offset] == " "
    " Remove the space from here.
    exec "normal" removeCommand
    let possible = 1
  endif

  " Move back into the word.
  exec "normal" savedCol . "|"
  if possible == 1
    exec "normal" pasteCommand
  endif
  " Move to the word start.
  exec "normal" savedCol . "|"
  exec "normal" moveToWordStart
endfunction


" Reads a normal mode mapping at the command line and executes it with the
"   given prefix.
function! ExecMap(prefix)
  let map = input("Enter Map: ")
  if map != ""
    exec "normal " . a:prefix . map
  endif
endfunction


" If lhs is already mapped, this function makes sure rhs is appended to it
"   instead of overwriting it.
" mapMode is used to prefix to "oremap" and used as the map command. E.g., if
"   mapMode is 'n', then the function call results in the execution of noremap
"   command.
function! MapAppendCascaded(lhs, rhs, mapMode)

  " Determine the map mode from the map command.
  let mapChar = strpart(a:mapMode, 0, 1)

  " Check if this is already mapped.
  let oldrhs = maparg(a:lhs, mapChar)
  if oldrhs != ""
    let self = oldrhs
  else
    let self = a:lhs
  endif
  "echomsg a:mapMode . "oremap" . " " . a:lhs . " " . self . a:rhs
  exec a:mapMode . "oremap" a:lhs self . a:rhs
endfunction


"" 
"" Sort utilities.
""

"
" Comapare functions.
"

function! s:CmpByLineLength(line1, line2, direction)
  return a:direction * (strlen(a:line1) - strlen(a:line2))
endfunction

""
"" Sort infrastructure. {{{
""

"
" To Sort a range of lines, pass the range to QSort() along with the name of a
" function that will compare two lines.
"
function! QSort(cmp,direction) range
  call s:QSortR(a:firstline, a:lastline, a:cmp, a:direction)
endfunction


"
" Sort lines.  SortR() is called recursively.
"
function! s:QSortR(start, end, cmp, direction)
  if a:end > a:start
    let low = a:start
    let high = a:end

    " Arbitrarily establish partition element at the midpoint of the data.
    let midStr = getline((a:start + a:end) / 2)

    " Loop through the data until indices cross.
    while low <= high

      " Find the first element that is greater than or equal to the partition
      "   element starting from the left Index.
      while low < a:end
        let str = getline(low)
        exec "let result = " . a:cmp . "(str, midStr, " . a:direction . ")"
        if result < 0
          let low = low + 1
        else
          break
        endif
      endwhile

      " Find an element that is smaller than or equal to the partition element
      "   starting from the right Index.
      while high > a:start
        let str = getline(high)
        exec "let result = " . a:cmp . "(str, midStr, " . a:direction . ")"
        if result > 0
          let high = high - 1
        else
          break
        endif
      endwhile

      " If the indexes have not crossed, swap.
      if low <= high
        " Swap lines low and high.
        let str2 = getline(high)
        call setline(high, getline(low))
        call setline(low, str2)
        let low = low + 1
        let high = high - 1
      endif
    endwhile

    " If the right index has not reached the left side of data must now sort
    "   the left partition.
    if a:start < high
      call s:QSortR(a:start, high, a:cmp, a:direction)
    endif

    " If the left index has not reached the right side of data must now sort
    "   the right partition.
    if low < a:end
      call s:QSortR(low, a:end, a:cmp, a:direction)
    endif
  endif
endfunction

""" END: Sort InfraSetup. }}}


" Eats character if it matches the given pattern.
"
" Originally,
" From: Benji Fisher <fisherbb@bc.edu>
" Date: Mon, 25 Mar 2002 15:05:14 -0500
"
" Based on Bram's idea of eating a character while type <Space> to expand an
"   abbreviation. This solves the problem with abbreviations, where we are
"   left with an extra space after the expansion.
" Ex:
"   inoreabbr \date\ <C-R>=strftime("%d-%b-%Y")<CR><C-R>=EatChar('\s')<CR>
function! EatChar(pat)
   let c = nr2char(getchar())
   return (c =~ a:pat) ? '' : c
endfun

" vim6:fdm=marker
