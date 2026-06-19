vim9script

import autoload 'whhid/api.vim' as Api
import autoload 'whhid/config.vim' as Cfg

# ── board buffer name ────────────────────────────────────────────────────────
const BUFNAME = '__whhid_board__'

# line → {type: 'card'|'list', card: dict, list: dict}
var line_map: dict<dict<any>> = {}
# current board data (lists + cards)
var current_board: dict<any> = {}

# ── public commands ──────────────────────────────────────────────────────────

export def Open(): void
  if !Cfg.EnsureToken()
    echohl WarningMsg | echo 'WHHID: token required' | echohl None
    return
  endif
  var board_id = Cfg.GetBoardId()
  if board_id == -1
    echo 'WHHID: no board linked — run :WhhidLink first'
    return
  endif
  OpenBoardBuffer()
  echo 'WHHID: loading board…'
  Api.GetBoard(board_id, (board) => {
    current_board = board
    RenderBoard(board)
  }, (err) => EchoErr(err))
enddef

export def Link(): void
  if !Cfg.EnsureToken()
    echohl WarningMsg | echo 'WHHID: token required' | echohl None
    return
  endif
  echo 'WHHID: loading projects…'
  Api.ListProjects((projects) => {
    if empty(projects)
      EchoErr('No projects found')
      return
    endif
    var labels = mapnew(projects, (_, p) => p.name)
    popup_menu(labels, {
      title: ' Select project ',
      border: [1, 1, 1, 1],
      padding: [0, 1, 0, 1],
      callback: (_, idx) => PickProject(projects, idx)
    })
  }, (err) => EchoErr(err))
enddef

def PickProject(projects: list<any>, idx: number): void
  if idx < 1 | return | endif
  var project = projects[idx - 1]
  echo $'WHHID: loading boards for {project.name}…'
  Api.ListBoards(project.id, (boards) => {
    if empty(boards)
      EchoErr($'No boards found in project "{project.name}"')
      return
    endif
    var bnames = mapnew(boards, (_, b) => b.name)
    popup_menu(bnames, {
      title: ' Select board ',
      border: [1, 1, 1, 1],
      padding: [0, 1, 0, 1],
      callback: (_, bidx) => PickBoard(boards, bidx)
    })
  }, (err) => EchoErr(err))
enddef

def PickBoard(boards: list<any>, bidx: number): void
  if bidx < 1 | return | endif
  var board = boards[bidx - 1]
  Cfg.SetBoardId(board.id)
  echo $'WHHID: linked to "{board.name}"'
enddef

export def Unlink(): void
  Cfg.SetBoardId(-1)
  echo 'WHHID: board unlinked'
enddef

# ── board buffer ─────────────────────────────────────────────────────────────

def OpenBoardBuffer(): void
  # reuse existing window if open
  var winnr = bufwinnr(BUFNAME)
  if winnr > 0
    exe $'{winnr}wincmd w'
    return
  endif
  # open a left split
  exe $'topleft 40vsplit {BUFNAME}'
  setlocal buftype=nofile bufhidden=wipe noswapfile nowrap nobuflisted
  setlocal cursorline signcolumn=no nonumber norelativenumber
  setlocal filetype=whhid
  # mappings
  nnoremap <buffer> <CR>  <ScriptCmd>BoardEnter()<CR>
  nnoremap <buffer> m     <ScriptCmd>BoardMove()<CR>
  nnoremap <buffer> a     <ScriptCmd>BoardSendToAI()<CR>
  nnoremap <buffer> r     <ScriptCmd>BoardRefresh()<CR>
  nnoremap <buffer> q     <ScriptCmd>close<CR>
enddef

def RenderBoard(board: dict<any>): void
  var winnr = bufwinnr(BUFNAME)
  if winnr < 0 | return | endif
  exe $'{winnr}wincmd w'

  line_map = {}
  var lines: list<string> = [$' {board.name}', '']

  for lst in get(board, 'lists', [])
    var lnum = len(lines) + 1
    line_map[string(lnum)] = {type: 'list', list: lst}
    add(lines, $' ▸ {lst.name}')
    for card in get(lst, 'cards', [])
      var clnum = len(lines) + 1
      line_map[string(clnum)] = {type: 'card', card: card, list: lst}
      var icon = PriorityIcon(get(card, 'priority', ''))
      add(lines, $'   {icon} {card.title}')
    endfor
    add(lines, '')
  endfor

  add(lines, ' [r] refresh  [m] move  [a] AI  [q] close')

  setlocal modifiable
  deletebufline('%', 1, '$')
  setline(1, lines)
  setlocal nomodifiable
enddef

def BoardEnter(): void
  var lnum = line('.')
  var entry = get(line_map, string(lnum), {})
  if empty(entry) || entry.type != 'card' | return | endif
  OpenCardDetail(entry.card)
enddef

def BoardMove(): void
  var lnum = line('.')
  var entry = get(line_map, string(lnum), {})
  if empty(entry) || entry.type != 'card' | return | endif
  MoveCardUI(entry.card)
enddef

def BoardSendToAI(): void
  var lnum = line('.')
  var entry = get(line_map, string(lnum), {})
  if empty(entry) || entry.type != 'card' | return | endif
  echo 'WHHID: loading card…'
  Api.GetCard(entry.card.id, (card) => SendToAI(card), (err) => EchoErr(err))
enddef

def BoardRefresh(): void
  var board_id = Cfg.GetBoardId()
  if board_id == -1 | return | endif
  echo 'WHHID: refreshing…'
  Api.GetBoard(board_id, (board) => {
    current_board = board
    RenderBoard(board)
    echo 'WHHID: refreshed'
  }, (err) => EchoErr(err))
enddef

# ── card detail popup ────────────────────────────────────────────────────────

def OpenCardDetail(card: dict<any>): void
  echo 'WHHID: loading card…'
  Api.GetCard(card.id, (full) => ShowCardPopup(full), (err) => EchoErr(err))
enddef

def ShowCardPopup(card: dict<any>): void
  var lines: list<string> = []

  add(lines, $' {card.title}')
  add(lines, repeat('─', 50))

  var priority = get(card, 'priority', '')
  if !empty(priority) | add(lines, $' Priority : {priority}') | endif
  var assignee = get(card, 'assignee', v:none)
  if assignee isnot v:none && !empty(assignee)
    add(lines, $' Assignee : {assignee.name}')
  endif
  var due = get(card, 'due_date', '')
  if !empty(due) | add(lines, $' Due      : {due}') | endif
  var gh = get(card, 'github_link', '')
  if !empty(gh) | add(lines, $' GitHub   : {gh}') | endif

  var labels = get(card, 'labels', [])
  if !empty(labels)
    add(lines, $' Labels   : {join(mapnew(labels, (_, l) => l.name), ", ")}')
  endif

  var desc = get(card, 'description', '')
  if !empty(desc)
    add(lines, '')
    add(lines, ' Description:')
    for dline in split(desc, "\n")
      add(lines, $'  {dline}')
    endfor
  endif

  for cl in get(card, 'checklists', [])
    add(lines, '')
    add(lines, $' ☰ {cl.title}')
    for item in get(cl, 'items', [])
      var tick = item.completed ? '☑' : '☐'
      add(lines, $'  {tick} {item.title}')
    endfor
  endfor

  for cm in get(card, 'comments', [])
    add(lines, '')
    add(lines, $' {cm.user.name}:')
    add(lines, $'  {cm.body}')
  endfor

  add(lines, '')
  add(lines, repeat('─', 50))
  add(lines, '  [m] move   [a] send to AI   [q] close')

  # calculate popup size
  var width = max(mapnew(lines, (_, l) => strwidth(l))) + 2
  var height = min([len(lines), &lines - 6])

  popup_create(lines, {
    title: ' Card ',
    border: [1, 1, 1, 1],
    padding: [0, 1, 0, 1],
    minwidth: width,
    maxwidth: max([width, 70]),
    minheight: height,
    maxheight: height,
    scrollbar: 1,
    mapping: 0,
    filter: (winid, key) => CardPopupFilter(winid, key, card),
  })
enddef

def CardPopupFilter(winid: number, key: string, card: dict<any>): bool
  if key == 'q' || key == "\<Esc>"
    popup_close(winid)
    return true
  elseif key == 'm'
    popup_close(winid)
    MoveCardUI(card)
    return true
  elseif key == 'a'
    popup_close(winid)
    echo 'WHHID: loading card…'
    Api.GetCard(card.id, (full) => SendToAI(full), (err) => EchoErr(err))
    return true
  elseif key == "\<ScrollWheelUp>" || key == 'k'
    win_execute(winid, "normal! \<C-y>")
    return true
  elseif key == "\<ScrollWheelDown>" || key == 'j'
    win_execute(winid, "normal! \<C-e>")
    return true
  endif
  return false
enddef

# ── move card ────────────────────────────────────────────────────────────────

def MoveCardUI(card: dict<any>): void
  var lists = get(current_board, 'lists', [])
  if empty(lists)
    var board_id = Cfg.GetBoardId()
    if board_id == -1 | return | endif
    Api.GetBoard(board_id, (board) => {
      current_board = board
      PickList(card, board.lists)
    }, (err) => EchoErr(err))
  else
    PickList(card, lists)
  endif
enddef

def PickList(card: dict<any>, lists: list<any>): void
  var other_lists = filter(copy(lists), (_, l) => l.id != get(card, 'list_id', -1))
  var labels = mapnew(other_lists, (_, l) => l.name)
  popup_menu(labels, {
    title: ' Move to column ',
    border: [1, 1, 1, 1],
    padding: [0, 1, 0, 1],
    callback: (_, idx) => {
      if idx < 1 | return | endif
      var target = other_lists[idx - 1]
      echo $'WHHID: moving to "{target.name}"…'
      Api.MoveCard(card.id, target.id, () => {
        echo $'WHHID: moved to "{target.name}"'
        BoardRefresh()
      }, (err) => EchoErr(err))
    }
  })
enddef

# ── send to AI ───────────────────────────────────────────────────────────────

def SendToAI(card: dict<any>): void
  var lines: list<string> = []
  add(lines, $'# Task: {card.title}')
  var priority = get(card, 'priority', '')
  if !empty(priority) | add(lines, $'**Priority:** {priority}') | endif
  var due = get(card, 'due_date', '')
  if !empty(due) | add(lines, $'**Due:** {due}') | endif
  var gh = get(card, 'github_link', '')
  if !empty(gh) | add(lines, $'**GitHub:** {gh}') | endif
  var labels = get(card, 'labels', [])
  if !empty(labels)
    add(lines, $'**Labels:** {join(mapnew(labels, (_, l) => l.name), ", ")}')
  endif
  var desc = get(card, 'description', '')
  if !empty(desc)
    add(lines, '')
    add(lines, '## Description')
    add(lines, desc)
  endif
  for cl in get(card, 'checklists', [])
    add(lines, '')
    add(lines, $'## {cl.title}')
    for item in get(cl, 'items', [])
      var tick = item.completed ? 'x' : ' '
      add(lines, $'- [{tick}] {item.title}')
    endfor
  endfor
  for cm in get(card, 'comments', [])
    add(lines, '')
    add(lines, $'**{cm.user.name}:** {cm.body}')
  endfor
  add(lines, '')
  add(lines, '---')
  add(lines, 'Please help me implement or work on this task in the context of the current project.')

  var prompt = join(lines, "\n")
  setreg('+', prompt)
  setreg('"', prompt)
  echo 'WHHID: card prompt copied to clipboard — paste into your AI assistant'
enddef

# ── helpers ──────────────────────────────────────────────────────────────────

def PriorityIcon(priority: string): string
  if priority == 'urgent' | return '!!' | endif
  if priority == 'high'   | return '! ' | endif
  if priority == 'medium' | return '· ' | endif
  return '  '
enddef

def EchoErr(msg: string): void
  echohl ErrorMsg | echo $'WHHID: {msg}' | echohl None
enddef
