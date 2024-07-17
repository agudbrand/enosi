local Integer = {}
local UInteger = {}
local Bool = {}

local Union = {}
local union = function(...)
  return setmetatable({...}, Union)
end

local StrArray = {}

local Array = {}

local array = function(T)
  return setmetatable({T=T}, Array)
end

local Enum = {}

local stringedEnum = function(...)
  
end

local lsp = {}

lsp.ResourceOperationKind = stringedEnum
{
  Create = "create",
  Rename = "rename",
  Delete = "delete",
}

lsp.FailureHandlingKind = stringedEnum
{
  Abort = "abort",
  Transactional = "transactional",
  TextOnlyTransactional = "textOnlyTransactional",
  Undo = "undo",
}

lsp.SymbolKind = numericEnum
{
  "File",
  "Module",
  "Namespace",
  "Package",
  "Class",
  "Method",
  "Property",
  "Field",
  "Constructor",
  "Enum",
  "Interface",
  "Function",
  "Variable",
  "Constant",
  "String",
  "Number",
  "Boolean",
  "Array",
  "Object",
  "Key",
  "Null",
  "EnumMember",
  "Struct",
  "Event",
  "Operator",
  "TypeParameter",
}

lsp.SymbolTag = numericEnum
{
  "Deprecated",
}

lsp.MarkupKind = stringedEnum
{
  PlainText = "plaintext",
  Markdown = "markdown",
}

lsp.CompletionItemTab = numericEnum
{
  "Deprecated",
}

lsp.InsertTextMode = numericEnum
{
  "asIs",
  "adjustIndentation",
}

lsp.CompletionItemKind = numericEnum
{
  "Text",
  "Method",
  "Function",
  "Constructor",
  "Field",
  "Variable",
  "Class",
  "Interface",
  "Module",
  "Property",
  "Unit",
  "Value",
  "Enum",
  "Keyword",
  "Snippet",
  "Color",
  "File",
  "Reference",
  "Folder",
  "EnumMember",
  "Constant",
  "Struct",
  "Event",
  "Operator",
  "TypeParameter"
}

lsp.PrepareSupportDefaultBehavior = numericEnum
{
  "Identifier"
}

lsp.DiagnosticTag = numericEnum
{
  "Unecessary",
  "Deprecated",
}

lsp.CodeActionKind = stringedEnum
{
  Empty = "",
  QuickFix = "quickfix",
  Refactor = "refactor",
  RefactorExtract = "refactor.extract",
  RefactorInline = "refactor.inline",
  RefactorRewrite = "refactor.rewrite",
  Source = "source",
  SourceOrganizeImports = "source.organizeImports",
  SourceFixAll = "source.fixAll",
}

lsp.FoldingRangeKind = stringedEnum
{
  Comment = "comment",
  Imports = "imports",
  Region = "region",
}

lsp.TokenFormat = stringedEnum
{
  Relative = "relative",
}

lsp.PositionEncodingKind = stringedEnum
{
  UTF8 = "utf-8",
  UTF16 = "utf-16",
  UTF32 = "utf-32",
}

lsp.WorkspaceEditClientCapabilities =
{
  documentChanges = Bool,
  normalizesLineEndings = Bool,
  resourceOperations = lsp.ResourceOperationKind.Set,
  failureHandling = lsp.FailureHandlingKind.Set,
  changeAnnotationSupport =
  {
    groupsOnLabel = Bool,
  }
}

lsp.DidChangeConfigurationClientCapabilities =
{
  dynamicRegistration = Bool,
}

lsp.DidChangeWatchedFileClientCapabilities =
{
  dynamicRegistration = Bool,
  relativePathSupport = Bool,
}

lsp.WorkspaceSymbolClientCapabilities =
{
  dynamicRegistration = Bool,
  symbolKind =
  {
    valueSet = lsp.SymbolKind.Set
  },
  tagSupport =
  {
    valueSet = lsp.SymbolTag.Set
  },
  resolveSupport =
  {
    properties = StrArray,
  }
}

lsp.ExecuteCommandClientCapabilities =
{
  dynamicRegistration = Bool,
}

lsp.SemanticTokensWorkspaceClientCapabilities =
{
  refreshSupport = Bool,
}

lsp.CodeLensWorkspaceClientCapabilities =
{
  refreshSupport = Bool,
}

lsp.InlineValueWorkspaceClientCapabilities =
{
  refreshSupport = Bool,
}

lsp.InlayHintWorkspaceClientCapabilities =
{
  refreshSupport = Bool,
}

lsp.DiagnosticWorkspaceClientCapabilities =
{
  refreshSupport = Bool
}

local cc = setmetatable({},
{
  __newindex = function(self, key, val)
    lsp[key.."ClientCapabilities"] = val
    rawset(self, key, val)
  end
})

cc.TextDocumentSync =
{
  dynamicRegistration = Bool,
  willSave = Bool,
  willSaveWaitUntil = Bool,
  didSave = Bool,
}

cc.Completion =
{
  dynamicRegistration = Bool,
  completionItem =
  {
    snippetSupport = Bool,
    commitCharactersSupport = Bool,
    documentationFormat = lsp.MarkupKind.Set,
    deprecatedSupport = Bool,
    preselectSupport = Bool,
    tagSupport =
    {
      valueSet = lsp.CompletionItemTab.Set
    },
    insertReplaceSupport = Bool,
    resolveSupport =
    {
      properties = StrArray,
    },
    insertTextModeSupport =
    {
      valueSet = lsp.InsertTextMode.Set,
    },
    labelDetailsSupport = Bool,
  },
  completionItemKind =
  {
    valueSet = lsp.CompletionItemKind.Set
  },
  contextSupport = Bool,
  insertTextMode = lsp.InsertTextMode,
  completionList =
  {
    itemDefaults = StrArray,
  }
}

cc.Hover =
{
  dynamicRegistration = Bool,
  contentFormat = lsp.MarkupKind,
}

cc.SignatureHelp =
{
  dynamicRegistration = Bool,
  signatureInformation =
  {
    documentationFormat = lsp.MarkupKind,
    parameterInformation =
    {
      labelOffsetSupport = Bool,
    },
    activeParameterSupport = Bool,
  },
  contextSupport = Bool,
}

cc.Declaration =
{
  dynamicRegistration = Bool,
  linkSupport = Bool,
}

cc.Definition =
{
  dynamicRegistration = Bool,
  linkSupport = Bool,
}

cc.TypeDefinition =
{
  dynamicRegistration = Bool,
  linkSupport = Bool,
}

cc.Implementation =
{
  dynamicRegistration = Bool,
  linkSupport = Bool,
}

cc.Reference =
{
  dynamicRegistration = Bool,
}

cc.DocumentHighlight =
{
  dynamicRegistration = Bool,
}

cc.DocumentSymbol =
{
  dynamicRegistration = Bool,
  symbolKind =
  {
    valueSet = lsp.SymbolKind.Set,
  },
  hierarchicalDocumentSymbolSupport = Bool,
  tagSupport =
  {
    valueSet = lsp.SymbolTag.Set
  },
  labelSupport = Bool,
}

cc.CodeAction =
{
  dynamicRegistration = Bool,
  codeActionLiteralSupport =
  {
    codeActionKind =
    {
      valueSet = lsp.CodeActionKind.Set,
    }
  },
  isPreferredSupport = Bool,
  disabledSupport = Bool,
  dataSupport = Bool,
  resolveSupport =
  {
    properties = StrArray,
  },
  honorsChangeAnnotations = Bool,
}

cc.CodeLens =
{
  dynamicRegistration = Bool,
}

cc.DocumentLink =
{
  dynamicRegistration = Bool,
  tooltipSupport = Bool,
}

cc.DocumentColor =
{
  dynamicRegistration = Bool,
}

cc.DocumentFormatting =
{
  dynamicRegistration = Bool,
}

cc.DocumentRangeFormatting =
{
  dynamicRegistration = Bool,
}

cc.DocumentOnTypeFormatting =
{
  dynamicRegistration = Bool,
}

cc.Rename =
{
  dynamicRegistration = Bool,
  prepareSupport = Bool,
  prepareSupportDefaultBehavior = lsp.PrepareSupportDefaultBehavior,
  honorsChangeAnnotations = Bool,
}

cc.PublishDiagnostics =
{
  relatedInformation = Bool,
  tagSupport =
  {
    valueSet = lsp.DiagnosticTag.Set
  },
  versionSupport = Bool,
  codeDescriptionSupport = Bool,
  dataSupport = Bool,
}

cc.FoldingRange =
{
  dynamicRegistration = Bool,
  rangeLimit = UInteger,
  lineFoldingOnly = Bool,
  foldingRangeKind =
  {
    valueSet = lsp.FoldingRangeKind.Set
  },
  foldingRange =
  {
    collapsedText = Bool,
  }
}

cc.SelectionRange =
{
  dynamicRegistration = Bool,
}

cc.LinkedEditingRange =
{
  dynamicRegistration = Bool,
}

cc.CallHierarchy =
{
  dynamicRegistration = Bool,
}

cc.SemanticTokens =
{
  dynamicRegistration = Bool,
  requests =
  {
    range = Bool,
    full = union(Bool,
    {
      delta = Bool,
    })
  },
  tokenTypes = StrArray,
  tokenModifiers = StrArray,
  formats = array(lsp.TokenFormat),
  overlappingTokenSupport = Bool,
  multilineTokenSupport = Bool,
  serverCancelSupport = Bool,
  augmentsSyntaxToken = Bool,
}

cc.Moniker =
{
  dynamicRegistration = Bool,
}

cc.TypeHierarchy =
{
  dynamicRegistration = Bool,
}

cc.InlineValue =
{
  dynamicRegistration = Bool,
}

cc.InlayHint =
{
  dynamicRegistration = Bool,
  resolveSupport =
  {
    properties = StrArray,
  }
}

cc.Diagnostic =
{
  dynamicRegistration = Bool,
  relatedDocumentSupport = Bool,
}

lsp.TextDocumentClientCapabilities =
{
  synchronization = cc.TextDocumentSync,
  completion = cc.Completion,
  hover = cc.Hover,
  signatureHelp = cc.SignatureHelp,
  declaration = cc.Declaration,
  definition = cc.Definition,
  typeDefinition = cc.TypeDefinition,
  implementation = cc.Implementation,
  references = cc.Reference,
  documentHighlight = cc.DocumentHighlight,
  documentSymbol = cc.DocumentSymbol,
  codeAction = cc.CodeAction,
  codeLens = cc.CodeLens,
  documentLink = cc.DocumentLink,
  colorProvider = cc.DocumentColor,
  formatting = cc.DocumentFormatting,
  rangeFormatting = cc.DocumentRangeFormatting,
  onTypeFormatting = cc.DocumentOnTypeFormatting,
  rename = cc.Rename,
  publishDiagnostics = cc.PublishDiagnostics,
  foldingRange = cc.FoldingRange,
  selectionRange = cc.SelectionRange,
  linkedEditingRange = cc.LinkedEditingRange,
  callHierarchy = cc.CallHierarchy,
  semanticTokens = cc.SemanticTokens,
  moniker = cc.Moniker,
  typeHierarchy = cc.TypeHierarchy,
  inlineValue = cc.InlineValue,
  inlayHint = cc.InlayHint,
  diagnostic = cc.Diagnostic,
}

cc.ShowMessageRequest =
{
  messageActionItem =
  {
    additionalPropertySupport = Bool,
  }
}

cc.ShowDocument =
{
  support = Bool,
}

cc.RegularExpressions =
{
  engine = string,
  version = string,
}

cc.Markdown =
{
  parser = string,
  version = string,
  allowedTags = StrArray,
}

lsp.ClientCapabilities =
{
  workspace =
  {
    applyEdit = Bool,
    workspaceEdit = lsp.WorkspaceEditClientCapabilities,
    didChangeConfiguration = lsp.DidChangeConfigurationClientCapabilities,
    didChangeWatchedFiles = lsp.DidChangeWatchedFileClientCapabilities,
    symbol = lsp.WorkspaceSymbolClientCapabilities,
    executeCommand = lsp.ExecuteCommandClientCapabilities,
    workspaceFolders = Bool,
    configuration = Bool,
    semanticTokens = lsp.SemanticTokensWorkspaceClientCapabilities,
    codeLens = lsp.CodeLensWorkspaceClientCapabilities,
    fileOperations =
    {
      dynamicRegistration = Bool,
      didCreate = Bool,
      willCreate = Bool,
      didRename = Bool,
      willRename = Bool,
      didDelete = Bool,
      willDelete = Bool,
    },
    inlineValue = lsp.InlineValueWorkspaceClientCapabilities,
    inlayHint = lsp.InlayHintWorkspaceClientCapabilities,
    diagnostics = lsp.DiagnosticWorkspaceClientCapabilities,
  },
  textDocument = cc.TextDocumentClientCapabilities,
  window =
  {
    workDoneProgress = Bool,
    showMessage = cc.ShowMessageRequest,
    showDocument = cc.ShowDocument,
  },
  general =
  {
    stateRequestSupport =
    {
      cancel = Bool,
      retryOnContentModified = StrArray,
    },
    regularExpressions = cc.RegularExpressions,
    markdown = cc.Markdown,
  },
  positionEncodings = lsp.PositionEncodingKind.Set,
}

lsp.InitializeParams =
{
  processId = union(Integer, nil),

  clientInfo =
  {
    name = string,
    version = string,
  },

  locale = string,
  rootUri = string,
  capabilities = lsp.ClientCapabilities,

}
