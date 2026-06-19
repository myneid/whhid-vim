vim9script

import autoload 'whhid/api.vim' as Api
import autoload 'whhid/config.vim' as Cfg

const BUFNAME = '__whhid_board__'

var line_map: dict<dict<any>> = {}
var current_board: dict<any> = {}

# stash for link flow — Vim9 can't close over vars across async boundaries
var link_projects: list<any> = []
var link_boards: list<any> = []
# stash for move flow
var move_card_ref: dict<any> = {}

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
  Api.GetBoard(board_id, OnBoardLoaded, (err) => EchoErr(err))
enddef

export def Link(): void
  if !Cfg.EnsureToken()
    echohl WarningMsg | echo 'WHHID: token required' | echohl None
    return
  endif
  echo 'WHHID: loading projects…'
  Api.ListProjects(OnProjectsLoaded, (err) => EchoErr(err))
enddef

export def Unlink(): void
  Cfg.SetBoardId(-1)
  echo 'WHHID: board unlinked'
enddef

# ── link flow callbacks ──────────────────────────────────────────────────────

def OnProjectsLoaded(projects: any): void
  if empty(projects)
    EchoErr('No projects found')
    return
  endif
  link_projects = projects
  var labels = mapnew(link_projects, (_, p) => p.name)
  popup_menu(labels, {
    title: ' Select project ',
    border: [1, 1, 1, 1],
    padding: [0, 1, 0, 1],
    callback: (_, idx) => PickProject(idx)
  })
enddef

def PickProject(idx: number): void
  if idx < 1 | return | endif
  var project = link_projects[idx - 1]
  echo $'WHHID: loading boards for {project.name}…'
  Api.ListBoards(project.id, OnBoardsLoaded, (err) => EchoErr(err))
enddef

def OnBoardsLoaded(boards: any): void
  if empty(boards)
    EchoErr('No boards found in this project')
    return
  endif
  link_boards = boards
  var bnames = mapnew(link_boards, (_, b) => b.name)
  popup_menu(bnames, {
    title: ' Select board ',
    border: [1, 1, 1, 1],
    padding: [0, 1, 0, 1],
    callback: (_, bidx) => PickBoard(bidx)
  })
enddef

def PickBoard(bidx: number): void
  if bidx < 1 | return | endif
  var board = link_boards[bidx - 1]
  Cfg.SetBoardId(board.id)
  echo $'WHHID: linked to "{board.name}"'
enddef

# ── board buffer ─────────────────────────────────────────────────────────────

def OpenBoardBuffer(): void
  var winnr = bufwinnr(BUFNAME)
  if winnr > 0
    win_gotoid(win_getid(winnr))
    return
  endif
  exe 'topleft vsplit ' .. BUFNAME
  vertical resize 40
  setlocal buftype=nofile bufhidden=wipe noswapfile nowrap nobuflisted
  setlocal cursorline signcolumn=no nonumber norelativenumber
  setlocal filetype=whhid
  nnoremap <buffer> <CR>  <ScriptCmd>BoardEnter()<CR>
  nnoremap <buffer> m     <ScriptCmd>BoardMove()<CR>
  nnoremap <buffer> a     <ScriptCmd>BoardSendToAI()<CR>
  nnoremap <buffer> r     <ScriptCmd>BoardRefresh()<CR>
  nnoremap <buffer> q     <ScriptCmd>close<CR>
enddef

def OnBoardLoaded(board: any): void
  current_board = board
  RenderBoard(board)
enddef

def RenderBoard(board: dict<any>): void
  var winnr = bufwinnr(BUFNAME)
  if winnr < 0 | return | endif
  win_gotoid(win_getid(winnr))

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
  var entry = get(line_map, string(line('.')), {})
  if empty(entry) || entry.type != 'card' | return | endif
  OpenCardDetail(entry.card)
enddef

def BoardMove(): void
  var entry = get(line_map, string(line('.')), {})
  if empty(entry) || entry.type != 'card' | return | endif
  MoveCardUI(entry.card)
enddef

def BoardSendToAI(): void
  var entry = get(line_map, string(line('.')), {})
  if empty(entry) || entry.type != 'card' | return | endif
  echo 'WHHID: loading card…'
  Api.GetCard(entry.card.id, (card) => SendToAI(card), (err) => EchoErr(err))
enddef

def BoardRefresh(): void
  var board_id = Cfg.GetBoardId()
  if board_id == -1 | return | endif
  echo 'WHHID: refreshing…'
  Api.GetBoard(board_id, (board) => OnBoardLoaded(board), (err) => EchoErr(err))
enddef

# ── card detail popup ────────────────────────────────────────────────────────

def OpenCardDetail(card: dict<any>): void
  echo 'WHHID: loading card…'
  Api.GetCard(card.id, ShowCardPopup, (err) => EchoErr(err))
enddef

def ShowCardPopup(card: any): void
  var lines: list<string> = []
  add(lines, $' {card.title}')
  add(lines, repeat('─', 50))

  var priority = get(card, 'priority', '')
  if !empty(priority) | add(lines, $' Priority : {priority}') | endif
  var assignee = get(card, 'assignee', {})
  if !empty(assignee) | add(lines, $' Assignee : {assignee.name}') | endif
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

  var width = max(mapnew(lines, (_, l) => strwidth(l))) + 2
  var height = min([len(lines), &lines - 6])

  move_card_ref = card
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
    filter: CardPopupFilter,
  })
enddef

def CardPopupFilter(winid: number, key: string): bool
  if key == 'q' || key == "\<Esc>"
    popup_close(winid)
  elseif key == 'm'
    popup_close(winid)
    MoveCardUI(move_card_ref)
  elseif key == 'a'
    popup_close(winid)
    SendToAI(move_card_ref)
  elseif key == "\<ScrollWheelUp>" || key == 'k'
    win_execute(winid, "normal! \<C-y>")
  elseif key == "\<ScrollWheelDown>" || key == 'j'
    win_execute(winid, "normal! \<C-e>")
  endif
  return true
enddef

# ── move card ────────────────────────────────────────────────────────────────

def MoveCardUI(card: dict<any>): void
  move_card_ref = card
  var lists = get(current_board, 'lists', [])
  if empty(lists)
    var board_id = Cfg.GetBoardId()
    if board_id == -1 | return | endif
    Api.GetBoard(board_id, OnBoardForMove, (err) => EchoErr(err))
  else
    PickList(lists)
  endif
enddef

def OnBoardForMove(board: any): void
  current_board = board
  PickList(board.lists)
enddef

def PickList(lists: list<any>): void
  var other = filter(copy(lists), (_, l) => l.id != get(move_card_ref, 'list_id', -1))
  if empty(other)
    EchoErr('No other columns to move to')
    return
  endif
  var labels = mapnew(other, (_, l) => l.name)
  popup_menu(labels, {
    title: ' Move to column ',
    border: [1, 1, 1, 1],
    padding: [0, 1, 0, 1],
    callback: (_, idx) => DoMoveCard(other, idx)
  })
enddef

def DoMoveCard(lists: list<any>, idx: number): void
  if idx < 1 | return | endif
  var target = lists[idx - 1]
  echo $'WHHID: moving to "{target.name}"…'
  Api.MoveCard(move_card_ref.id, target.id, OnCardMoved, (err) => EchoErr(err))
enddef

def OnCardMoved(): void
  echo 'WHHID: moved'
  BoardRefresh()
enddef

# ── send to AI ───────────────────────────────────────────────────────────────

def SendToAI(card: dict<any>): void
  var lines: list<string> = [$'# Task: {card.title}']
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
      add(lines, $'- [{item.completed ? "x" : " "}] {item.title}')
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
  echo 'WHHID: card prompt copied to clipboard'
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
