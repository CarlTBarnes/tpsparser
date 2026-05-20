!05/20/26 by Carl Barnes to test new method in class DebugClassWindow() 
!                        to view Queues and other data in class to understand how it works
!            After press BUTTON('Parse') to load TPS file
!            Press BUTTON('Debug') to see Debug Window
!------------------------------------------------------------------------------------
! TpsParser.CLW added PRAGMA('link(C%V%DOS%X%%L%.LIB)') so project does not need to add DOS Driver
  PROGRAM

  INCLUDE('TpsParser.inc'),ONCE

Msg                 ANY
  MAP
AppendMsg   PROCEDURE(STRING pMsg,<STRING pSep>) 
  .
crlf                EQUATE('<13,10>')
comma               EQUATE(',')

TpsFileName         STRING(255)
TmpFileName         STRING(255)

TpsOwner            STRING(100)

Window WINDOW('TPS File Parser - Test DebugClassWindow() Method'),AT(,,506,245),AUTO,SYSTEM,FONT('Segoe UI',10)
        PROMPT('TPS File:'),AT(5,5,,10),USE(?TpsFileName:Prompt)
        ENTRY(@S255),AT(38,5,167,10),USE(TpsFileName)
        BUTTON('Browse'),AT(209,5,,10),USE(?TpsFileName:browse)
        PROMPT('Owner:'),AT(258,5,,10),USE(?TpsOwner:Prompt)
        ENTRY(@S100),AT(286,5,131,10),USE(TpsOwner)
        BUTTON('Parse'),AT(433,5,31,10),USE(?Parse),FONT(,,,FONT:bold),DEFAULT
        BUTTON('Debug'),AT(469,5,32,10),USE(?DebugBtn)
        TEXT,AT(5,20,495,220),USE(?msg),SKIP,VSCROLL,FONT('Lucida Console',,,FONT:regular),READONLY
    END

Last_TpsParse  &TpsParserType      !Workaround Class declared in routine
  CODE
  TpsFileName='CUSTOMER.TPS'
  TpsFileName='ORDERS.TPS'
  TpsFileName='TpsSamples\Zuper.TPS' 
  IF TpsFileName AND ~EXISTS(TpsFileName) THEN TpsFileName=''.
  OPEN(Window)
  ACCEPT
    CASE ACCEPTED()
      OF ?TpsFileName:browse
        IF FILEDIALOG('TPS Files',TmpFileName,'(*.tps)|*.tps',FILE:KeepDir+FILE:LongName+FILE:AddExtension)
          TpsFileName = TmpFileName
        .                
      OF ?Parse
        DO Parse 
        ?msg{PROP:Text} = Msg
     
      OF ?DebugBtn
        IF Last_TpsParse &= NULL THEN 
            Message('Please Parse a TPS file')
            CYCLE
        END
        Last_TpsParse.DebugClassWindow()    !New method to see inside class
    .
  .
  
Parse               ROUTINE
  DATA
idxTable    LONG
idxField    LONG
idxRecords  LONG
!tp  TpsParserType
tp  &TpsParserType   !Workaround Class in routine
  CODE
  DISPOSE(Last_TpsParse)                    !Workaround Class in routine
  Last_TpsParse &= NEW(TpsParserType)       !by delcare in procedure 
  tp &= Last_TpsParse
  Msg = ''
  IF TpsOwner
    IF tp.Init(TpsFileName,TpsOwner)
      AppendMsg(tp.GetError())
      EXIT
    .
  ELSE
    IF tp.Init(TpsFileName)
      AppendMsg(tp.GetError())
      EXIT
    .
  .
  LOOP idxTable = 1 TO tp.Tables()
    AppendMsg('Table '&idxTable&' '&tp.GetTableName(idxTable),crlf)
    tp.SetTable(idxTable)
    LOOP idxField = 1 TO tp.Fields()
      AppendMsg('   '&LEFT(tp.GetFieldNameByNumber(idxField),25),crlf)
      AppendMsg(tp.GetFieldTypeByNumber(idxField),' ')
      AppendMsg(tp.GetFieldSizeByNumber(idxField),' ')
    .    
    AppendMsg(crlf)
    AppendMsg(crlf)
    LOOP idxField = 1 TO tp.Fields()
      AppendMsg(tp.GetFieldNameByNumber(idxField))
      IF idxField < tp.Fields()
        AppendMsg(comma)
      .      
    .    
    AppendMsg(crlf)
    tp.Set
    LOOP UNTIL tp.Next()
      idxRecords += 1
      IF idxRecords > 3 THEN BREAK.
      LOOP idxField = 1 TO tp.Fields()
        AppendMsg(CLIP(tp.GetFieldByNumber(idxField)))
        IF idxField < tp.Fields()
          AppendMsg(comma)
        .      
      .    
      AppendMsg(crlf)
    .    
    AppendMsg(crlf)
  .
  tp.SetTable(1)    !Leave Table 1 loaded in Class for the Debug Window
  
AppendMsg           PROCEDURE(STRING pMsg,<STRING pSep>) 
  CODE
  IF NOT OMITTED(pSep) AND LEN(pSep) AND Msg 
    Msg = Msg & pSep
  .  
  Msg = Msg & pMsg
