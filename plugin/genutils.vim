"
" Useful buffer, file and window related functions.
"
" Author: Hari <hari_vim@yahoo.com>
" Last Modified: 06-Mar-2002 @ 19:30:22
" Requires: Vim-6.0, multvals.vim(2.0.5)
" Version: 1.0.15
" Description:
"   - A scriptlet to pass variable number of arguments to other functions.
"   - Misc. window/buffer related functions, NumberOfWindows(),
"     FindWindowForBuffer(), FindBufferForName(), MoveCursorToWindow(),
"     MoveCurLineToWinLine(), SetupScratchBuffer(),
"   - Save/Restore all the window height/width settings to be restored later.
"   - Save/Restore position in the buffer to be restored later. Works like the
"     built-in marks feature, but has more to it.
"   - NotifyWindowClose() to get notifications *after* a window with the
"     specified buffer has been closed or the buffer is unloaded. The built-in
"     autocommands can only notify you *before* the window is closed. You can
"     use this with the Save/Restore window settings feature to restore the
"     user windows, after your window is closed.
"   - ShowLinesWithSyntax() function to echo lines with syntax coloring.
"   - ShiftWordInSpace() a small utility function to move words in the
"     space without changing the width of the field.
"   - A quick-sort function that can sort a buffer contents by range. Adds
"     utility commands SortByLength and RSortByLength to sort contents by line
"     length.
"   - A sample function to extract the scriptId of a script.
"

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
    \    exec 'let nextArgument = a:' . argCounter\n
    \    let nextArgument = substitute(nextArgument,
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


" Turn on some buffer settings that make it suitable to be a scratch buffer.
function! SetupScratchBuffer()
  setlocal noswapfile
  setlocal nobuflisted
  setlocal buftype=nofile
  " Just in case, this will make sure we are always hidden.
  setlocal bufhidden=delete
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
  if !exists("s:notifyWindowTitles")
    return
  endif

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
  if !exists("s:notifyWindowTitles")
    return
  endif

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


"nnoremap <silent> \ :call ExecMap('\')<CR>
"function! ExecMap(prefix)
"  let map = input("Enter Map: ")
"  exec "normal " . a:prefix . map
"endfunction


"" 
"" Sort utilities.
""

command! -nargs=0 -range=% SortByLength <line1>,<line2>call QSort(
    \ 's:CmpByLineLength', 1)
command! -nargs=0 -range=% RSortByLength <line1>,<line2>call QSort(
    \ 's:CmpByLineLength', -1)

"
" Comapare functions.
"

function! s:CmpByLineLength(line1, line2, direction)
  return a:direction * (strlen(a:line1) - strlen(a:line2))
endfunction

""
"" Sort infrastructure.
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
