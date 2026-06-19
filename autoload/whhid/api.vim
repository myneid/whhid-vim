vim9script

export def CallTool(name: string, args: dict<any>, Callback: func(any), ErrCallback: func(string)): void
  var token = get(g:, 'whhid_token', '')
  if empty(token)
    ErrCallback('g:whhid_token is not set')
    return
  endif
  var url = get(g:, 'whhid_mcp_url', 'https://whatthehellhaveidone.net/mcp/whhid')

  var body = json_encode({
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {name: name, arguments: args}
  })

  var output: list<string> = []

  var job = job_start(
    ['curl', '-s', '-X', 'POST', url,
      '-H', 'Content-Type: application/json',
      '-H', 'Accept: application/json',
      '-H', $'Authorization: Bearer {token}',
      '--data-raw', body],
    {
      out_cb: (ch, line) => {
        add(output, line)
      },
      exit_cb: (j, status) => {
        HandleResponse(output, status, Callback, ErrCallback)
      }
    }
  )

  if job_status(job) ==# 'fail'
    ErrCallback('Failed to start curl — is curl installed?')
  endif
enddef

def HandleResponse(output: list<string>, status: number, Callback: func(any), ErrCallback: func(string)): void
  if status != 0
    ErrCallback($'curl exited with status {status}')
    return
  endif

  # Strip SSE "data: " prefixes if the server returned event-stream format
  var lines = mapnew(output, (_, l) => l =~# '^data: ' ? l[6 :] : l)
  # Drop SSE control lines (empty, "event:", "id:", etc.)
  lines = filter(lines, (_, l) => l =~# '^{')

  var raw = join(lines, '')
  if empty(raw)
    ErrCallback('Empty response from server')
    return
  endif

  var preview = raw->strpart(0, 200)
  try
    var resp = json_decode(raw)
    if type(resp) != v:t_dict
      ErrCallback($'Unexpected response type: {preview}')
      return
    endif
    if has_key(resp, 'error')
      ErrCallback($'MCP error: {resp.error.message}')
      return
    endif
    if !has_key(resp, 'result')
      ErrCallback($'No result in response: {preview}')
      return
    endif
    var content = get(resp.result, 'content', [])
    if empty(content)
      ErrCallback('Empty content in result')
      return
    endif
    var text = get(content[0], 'text', '')
    if empty(text)
      ErrCallback('No text in content block')
      return
    endif
    Callback(json_decode(text))
  catch
    ErrCallback($'Parse error ({v:exception}): {preview}')
  endtry
enddef

export def ListProjects(Callback: func(any), Err: func(string)): void
  CallTool('list-projects-tool', {}, (data) => {
    Callback(type(data) == v:t_list ? data : get(data, 'data', []))
  }, Err)
enddef

export def ListBoards(projectId: number, Callback: func(any), Err: func(string)): void
  CallTool('list-boards-tool', {project_id: projectId}, (data) => {
    Callback(type(data) == v:t_list ? data : get(data, 'data', []))
  }, Err)
enddef

export def GetBoard(boardId: number, Callback: func(any), Err: func(string)): void
  CallTool('get-board-tool', {board_id: boardId}, (data) => {
    Callback(has_key(data, 'data') ? data.data : data)
  }, Err)
enddef

export def GetCard(cardId: number, Callback: func(any), Err: func(string)): void
  CallTool('get-card-tool', {card_id: cardId}, (data) => {
    Callback(has_key(data, 'data') ? data.data : data)
  }, Err)
enddef

export def MoveCard(cardId: number, listId: number, Callback: func(), Err: func(string)): void
  CallTool('move-card-tool', {card_id: cardId, list_id: listId}, (_) => Callback(), Err)
enddef
