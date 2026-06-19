vim9script

var config_file = expand('~/.vim/whhid.json')

export def Load(): dict<any>
  if filereadable(config_file)
    try
      return json_decode(join(readfile(config_file), ''))
    catch
    endtry
  endif
  return {}
enddef

export def Save(cfg: dict<any>): void
  writefile([json_encode(cfg)], config_file)
enddef

export def Get(key: string): any
  var cfg = Load()
  return get(cfg, key, null)
enddef

export def Set(key: string, value: any): void
  var cfg = Load()
  cfg[key] = value
  Save(cfg)
enddef

export def EnsureToken(): bool
  if !empty(get(g:, 'whhid_token', ''))
    return true
  endif
  var saved = Get('token')
  if type(saved) == v:t_string && !empty(saved)
    g:whhid_token = saved
    return true
  endif
  var token = inputsecret('WHHID API token: ')
  if empty(token)
    return false
  endif
  g:whhid_token = token
  Set('token', token)
  return true
enddef

export def GetBoardId(): number
  # workspace-local first (stored per cwd)
  var cwd = fnamemodify(getcwd(), ':p')
  var cfg = Load()
  var workspaces: dict<any> = get(cfg, 'workspaces', {})
  if has_key(workspaces, cwd)
    return workspaces[cwd]->str2nr()
  endif
  return -1
enddef

export def SetBoardId(id: number): void
  var cwd = fnamemodify(getcwd(), ':p')
  var cfg = Load()
  if !has_key(cfg, 'workspaces')
    cfg.workspaces = {}
  endif
  cfg.workspaces[cwd] = id
  Save(cfg)
enddef
