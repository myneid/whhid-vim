vim9script

# Low-level MCP tool caller. Calls Callback(result_dict) on success,
# ErrCallback(message) on failure.
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
  job_start(
    ['curl', '-s', '-X', 'POST', url,
      '-H', 'Content-Type: application/json',
      '-H', 'Accept: application/json',
      '-H', $'Authorization: Bearer {token}',
      '--data-raw', body],
    {
      out_cb: (ch, line) => add(output, line),
      exit_cb: (job, status) => {
        if status != 0
          ErrCallback($'curl exited with status {status}')
          return
        endif
        var raw = join(output, '')
        try
          var resp = json_decode(raw)
          if has_key(resp, 'error')
            ErrCallback(resp.error.message)
            return
          endif
          var text = resp.result.content[0].text
          Callback(json_decode(text))
        catch
          ErrCallback($'JSON parse error: {v:exception}')
        endtry
      }
    }
  )
enddef

export def ListProjects(Callback: func(any), Err: func(string)): void
  CallTool('list-projects-tool', {}, (data) => {
    Callback(type(data) == v:t_list ? data : data.data)
  }, Err)
enddef

export def ListBoards(projectId: number, Callback: func(any), Err: func(string)): void
  CallTool('list-boards-tool', {project_id: projectId}, (data) => {
    Callback(type(data) == v:t_list ? data : data.data)
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
