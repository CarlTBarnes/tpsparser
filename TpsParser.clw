! ------------------------------------------------------------------------------
! TpsParserType
!
! Clarion TPS parser adapted from the Java ctrl-alt-dev/tps-parse project.
!
! Original project:
!   https://github.com/ctrl-alt-dev/tps-parse
!   Copyright (C) 2012-2021 E. Hooijmeijer / Erik Hooijmeijer
!   Licensed under the Apache License 2.0
!
! Local license copy:
!   Apache-2.0.txt
!
! Note:
!   TPS parsing is based on reverse-engineered file structures and may be
!   incomplete or misinterpret data. Verify output before relying on it.
! ------------------------------------------------------------------------------

  MEMBER

  MAP
  END

  INCLUDE('TpsParser.inc'),ONCE

TpsStringMax        EQUATE(1024)
TpsMemoStringMax    EQUATE(8192)
TpsWorkSlack        EQUATE(8192)
TpsFileNameMax      EQUATE(260)
TpsDosBufferMax     EQUATE(32768)
TpsDosReadMode      EQUATE(40H)
TpsMinHeaderLen     EQUATE(200H)
TpsBlockStartTable  EQUATE(20H)
TpsBlockEndTable    EQUATE(110H)
TpsFirstPageOffset  EQUATE(200H)
TpsPageScanStep     EQUATE(100H)
TpsAlignMask        EQUATE(0FFFFFF00H)
TpsBlockAddrShift   EQUATE(8)
TpsPageHeaderLen    EQUATE(13)
TpsSignatureOffset  EQUATE(14)
TpsSignatureLen     EQUATE(4)
TpsRecData          EQUATE(0F3H)
TpsRecMemo          EQUATE(0FCH)
TpsRecTableDef      EQUATE(0FAH)
TpsRecTableName     EQUATE(0FEH)
TpsFieldByte        EQUATE(1)
TpsFieldShort       EQUATE(2)
TpsFieldUShort      EQUATE(3)
TpsFieldDate        EQUATE(4)
TpsFieldTime        EQUATE(5)
TpsFieldLong        EQUATE(6)
TpsFieldULong       EQUATE(7)
TpsFieldFloat       EQUATE(8)
TpsFieldDouble      EQUATE(9)
TpsFieldBcd         EQUATE(0AH)
TpsFieldString      EQUATE(12H)
TpsFieldCString     EQUATE(13H)
TpsFieldPString     EQUATE(14H)
TpsFieldGroup       EQUATE(16H)
TpsMemoFieldType    EQUATE(0FCH)
TpsBlobFlag         EQUATE(4)
TpsBlobLenPrefix    EQUATE(4)
TpsFlagRecLen       EQUATE(128)
TpsFlagHeaderLen    EQUATE(64)
TpsFlagCopyLen      EQUATE(63)
TpsRleExtended      EQUATE(127)
TpsRleBase          EQUATE(128)
TpsKeySize          EQUATE(64)
TpsKeyWords         EQUATE(16)
TpsKeyIndexMask     EQUATE(3FH)
TpsKeyByteStep      EQUATE(11H)
TpsHeaderDecryptLen EQUATE(200H)
TpsByteMask         EQUATE(0FFH)
TpsWordNotMask      EQUATE(0FFFFFFFFH)

TpsParserType.Init  PROCEDURE(STRING pFileName)
Result                LONG
  CODE
  SELF.Kill()
  SELF.LastError = 0
  SELF.LastErrorText = ''
  Result = SELF.LoadSource(pFileName)
  IF Result <> 0
    RETURN Result
  END
  Result = SELF.ParseTps()
  IF Result <> 0
    RETURN Result
  END
  SORT(SELF.TableDefQ,+SELF.TableDefQ.TableNo,+SELF.TableDefQ.BlockNo)
  SORT(SELF.DataQ,+SELF.DataQ.TableNo,+SELF.DataQ.RecordNumber)
  SORT(SELF.MemoQ,+SELF.MemoQ.TableNo,+SELF.MemoQ.Owner,+SELF.MemoQ.MemoIndex,+SELF.MemoQ.Sequence)
  Result = SELF.SetTable(0)
  IF Result <> 0
    RETURN Result
  END
  RETURN SELF.SetLastError(0,'')

TpsParserType.Init  PROCEDURE(STRING pFileName,STRING pOwner)
Result                LONG
  CODE
  SELF.Kill()
  SELF.LastError = 0
  SELF.LastErrorText = ''
  Result = SELF.LoadSource(pFileName)
  IF Result <> 0
    RETURN Result
  END
  Result = SELF.DecryptSource(pOwner)
  IF Result <> 0
    RETURN Result
  END
  Result = SELF.ParseTps()
  IF Result <> 0
    RETURN Result
  END
  SORT(SELF.TableDefQ,+SELF.TableDefQ.TableNo,+SELF.TableDefQ.BlockNo)
  SORT(SELF.DataQ,+SELF.DataQ.TableNo,+SELF.DataQ.RecordNumber)
  SORT(SELF.MemoQ,+SELF.MemoQ.TableNo,+SELF.MemoQ.Owner,+SELF.MemoQ.MemoIndex,+SELF.MemoQ.Sequence)
  Result = SELF.SetTable(0)
  IF Result <> 0
    RETURN Result
  END
  RETURN SELF.SetLastError(0,'')

TpsParserType.Kill  PROCEDURE
  CODE
  IF ~SELF.Src &= NULL
    DISPOSE(SELF.Src)
  END
  IF ~SELF.WorkPage &= NULL
    DISPOSE(SELF.WorkPage)
  END
  FREE(SELF.DataQ)
  FREE(SELF.MemoQ)
  FREE(SELF.TableDefQ)
  FREE(SELF.TableNameQ)
  FREE(SELF.FieldQ)
  SELF.SrcLen = 0
  SELF.WorkPageLen = 0
  SELF.CurrentRecord = 0
  SELF.CurrentTable = 0

TpsParserType.GetErrorCode  PROCEDURE
  CODE
  RETURN SELF.LastError

TpsParserType.GetError  PROCEDURE
  CODE
  RETURN CLIP(SELF.LastErrorText)

TpsParserType.Tables    PROCEDURE
I                         LONG
Count                     LONG
LastNo                    LONG
  CODE
  SORT(SELF.TableDefQ,+SELF.TableDefQ.TableNo,+SELF.TableDefQ.BlockNo)
  Count = 0
  LastNo = -1
  LOOP I = 1 TO RECORDS(SELF.TableDefQ)
    GET(SELF.TableDefQ,I)
    IF SELF.TableDefQ.TableNo <> LastNo
      Count += 1
      LastNo = SELF.TableDefQ.TableNo
    END
  END
  RETURN Count

TpsParserType.GetTableName  PROCEDURE(LONG pTableIndex)
TableNo                       LONG
  CODE
  TableNo = SELF.ResolveTableNumber(pTableIndex)
  RETURN SELF.GetTableNameByTableNumber(TableNo)

TpsParserType.SetTable  PROCEDURE(LONG pTableIndex)
TableNo                   LONG
Result                    LONG
  CODE
  IF pTableIndex = 0
    pTableIndex = 1
  END
  TableNo = SELF.ResolveTableNumber(pTableIndex)
  IF TableNo = 0
    RETURN SELF.SetLastError(TpsErrTableIndex,'Invalid table index ' & pTableIndex & '; table count=' & SELF.Tables())
  END
  SELF.CurrentTable = TableNo
  SELF.CurrentRecord = 0
  Result = SELF.ParseTableLayout()
  IF Result <> 0
    RETURN Result
  END
  RETURN SELF.SetLastError(0,'')

TpsParserType.Records   PROCEDURE
I                         LONG
Count                     LONG
  CODE
  Count = 0
  LOOP I = 1 TO RECORDS(SELF.DataQ)
    GET(SELF.DataQ,I)
    IF SELF.DataQ.TableNo = SELF.CurrentTable
      Count += 1
    END
  END
  RETURN Count

TpsParserType.Get   PROCEDURE(LONG pRecordNo)
I                     LONG
Count                 LONG
  CODE
  IF pRecordNo < 1
    SELF.CurrentRecord = 0
    RETURN SELF.SetLastError(TpsErrRecordIndex,'Invalid record index ' & pRecordNo)
  END
  Count = 0
  LOOP I = 1 TO RECORDS(SELF.DataQ)
    GET(SELF.DataQ,I)
    IF SELF.DataQ.TableNo = SELF.CurrentTable
      Count += 1
      IF Count = pRecordNo
        SELF.CurrentRecord = I
        RETURN SELF.SetLastError(0,'')
      END
    END
  END
  SELF.CurrentRecord = 0
  RETURN SELF.SetLastError(TpsErrRecordNotFound,'Record index not found ' & pRecordNo & '; record count=' & Count)

TpsParserType.Set   PROCEDURE(LONG pRecordNo)
  CODE
  IF pRecordNo = 0
    SELF.CurrentRecord = 0
    RETURN SELF.SetLastError(0,'')
  END
  RETURN SELF.Get(pRecordNo)

TpsParserType.Next  PROCEDURE
  CODE
  LOOP
    SELF.CurrentRecord += 1
    IF SELF.CurrentRecord > RECORDS(SELF.DataQ)
      SELF.CurrentRecord = 0
      RETURN TRUE
    END
    GET(SELF.DataQ,SELF.CurrentRecord)
    IF SELF.DataQ.TableNo = SELF.CurrentTable
      RETURN FALSE
    END
  END

TpsParserType.Fields    PROCEDURE
  CODE
  RETURN RECORDS(SELF.FieldQ)

TpsParserType.GetFieldNameByNumber  PROCEDURE(LONG pFieldNo)
  CODE
  IF pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN ''
  END
  GET(SELF.FieldQ,pFieldNo)
  RETURN CLIP(SELF.FieldQ.ShortName)

TpsParserType.GetFieldType  PROCEDURE(STRING pFieldName)
  CODE
  RETURN SELF.GetFieldTypeByNumber(SELF.GetFieldNumber(pFieldName))

TpsParserType.GetFieldTypeByNumber  PROCEDURE(LONG pFieldNo)
  CODE
  IF pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN ''
  END
  GET(SELF.FieldQ,pFieldNo)
  RETURN CLIP(SELF.FieldQ.TypeName)

TpsParserType.GetFieldDimension PROCEDURE(STRING pFieldName)
  CODE
  RETURN SELF.GetFieldDimensionByNumber(SELF.GetFieldNumber(pFieldName))

TpsParserType.GetFieldDimensionByNumber PROCEDURE(LONG pFieldNo)
  CODE
  IF pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN 0
  END
  GET(SELF.FieldQ,pFieldNo)
  IF SELF.FieldQ.Elements > 1
    RETURN SELF.FieldQ.Elements
  END
  RETURN 0

TpsParserType.GetFieldSize  PROCEDURE(STRING pFieldName)
  CODE
  RETURN SELF.GetFieldSizeByNumber(SELF.GetFieldNumber(pFieldName))

TpsParserType.GetFieldSizeByNumber  PROCEDURE(LONG pFieldNo)
ElementLen                            LONG
  CODE
  IF pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN 0
  END
  GET(SELF.FieldQ,pFieldNo)
  IF SELF.FieldQ.IsMemo OR SELF.FieldQ.IsBlob
    RETURN 0
  END
  CASE SELF.FieldQ.FieldType
    OF TpsFieldBcd
      RETURN SELF.FieldQ.BcdLengthOfElement
    ELSE
      ElementLen = SELF.FieldQ.Length
      IF SELF.FieldQ.Elements > 1
        ElementLen = SELF.FieldQ.Length / SELF.FieldQ.Elements
      END
      RETURN ElementLen
  END

TpsParserType.GetFieldDecimals  PROCEDURE(STRING pFieldName)
  CODE
  RETURN SELF.GetFieldDecimalsByNumber(SELF.GetFieldNumber(pFieldName))

TpsParserType.GetFieldDecimalsByNumber  PROCEDURE(LONG pFieldNo)
  CODE
  IF pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN 0
  END
  GET(SELF.FieldQ,pFieldNo)
  IF SELF.FieldQ.FieldType = TpsFieldBcd
    RETURN SELF.FieldQ.BcdDigitsAfterDecimal
  END
  RETURN 0

TpsParserType.GetFieldNumber    PROCEDURE(STRING pFieldName)
I                                 LONG
Want                              STRING(TpsNameMax)
  CODE
  Want = UPPER(CLIP(pFieldName))
  LOOP I = 1 TO RECORDS(SELF.FieldQ)
    GET(SELF.FieldQ,I)
    IF UPPER(CLIP(SELF.FieldQ.ShortName)) = Want OR UPPER(CLIP(SELF.FieldQ.Name)) = Want
      RETURN I
    END
  END
  RETURN 0

TpsParserType.GetField  PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension)
  CODE
  IF pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN ''
  END
  GET(SELF.FieldQ,pFieldNo)
  IF SELF.FieldQ.IsMemo
    RETURN SELF.GetMemoFieldByNumber(pFieldNo)
  END
  IF SELF.FieldQ.IsBlob
    RETURN ''
  END
  CASE SELF.FieldQ.FieldType
    OF TpsFieldByte
      RETURN SELF.GetByteFieldByNumber(pFieldNo,pDimension)
    OF TpsFieldShort
      RETURN SELF.GetShortFieldByNumber(pFieldNo,pDimension)
    OF TpsFieldUShort
      RETURN SELF.GetUShortFieldByNumber(pFieldNo,pDimension)
    OF TpsFieldDate
      RETURN FORMAT(SELF.GetDateFieldByNumber(pFieldNo,pDimension),@D10-B)
    OF TpsFieldTime
      RETURN FORMAT(SELF.GetTimeFieldByNumber(pFieldNo,pDimension),@T04B)
    OF TpsFieldLong
      RETURN SELF.GetLongFieldByNumber(pFieldNo,pDimension)
    OF TpsFieldULong
      RETURN SELF.GetULongFieldByNumber(pFieldNo,pDimension)
    OF TpsFieldFloat OROF TpsFieldDouble
      RETURN SELF.GetRealFieldByNumber(pFieldNo,pDimension)
    OF TpsFieldBcd
      RETURN SELF.GetDecimalFieldByNumber(pFieldNo,pDimension)
    ELSE
      RETURN SELF.GetStringFieldByNumber(pFieldNo,pDimension)
  END

TpsParserType.GetStringField    PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetStringFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetStringFieldByNumber    PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                    LONG
Length                                    LONG
I                                         LONG
B                                         LONG
StrLen                                    LONG
Out                                       STRING(TpsStringMax)
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN ''
  END
  GET(SELF.FieldQ,pFieldNo)
  GET(SELF.DataQ,SELF.CurrentRecord)
  CASE SELF.FieldQ.FieldType
    OF TpsFieldCString
      CLEAR(Out)
      StrLen = 0
      LOOP I = 0 TO Length - 1
        B = SELF.ReadByte(SELF.DataQ.Payload,Offset + I)
        IF B = 0
          BREAK
        END
        IF StrLen < SIZE(Out)
          StrLen += 1
          Out[StrLen] = CHR(B)
        END
      END
      RETURN Out[1 : StrLen]
    OF TpsFieldPString
      CLEAR(Out)
      IF Length < 1
        RETURN ''
      END
      StrLen = SELF.ReadByte(SELF.DataQ.Payload,Offset)
      IF StrLen > Length - 1
        StrLen = Length - 1
      END
      IF StrLen > SIZE(Out)
        StrLen = SIZE(Out)
      END
      IF StrLen > 0
        Out[1 : StrLen] = SELF.DataQ.Payload[Offset + 2 : Offset + 1 + StrLen]
      END
      RETURN Out[1 : StrLen]
    ELSE
      RETURN SELF.Slice(SELF.DataQ.Payload,Offset,Length)
  END

TpsParserType.GetByteField  PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetByteFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetByteFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                LONG
Length                                LONG
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN 0
  END
  IF Length < 1
    RETURN 0
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  RETURN SELF.ReadByte(SELF.DataQ.Payload,Offset)

TpsParserType.GetShortField PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetShortFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetShortFieldByNumber PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                LONG
Length                                LONG
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN 0
  END
  IF Length < 2
    RETURN 0
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  RETURN SELF.ReadLeShort(SELF.DataQ.Payload,Offset)

TpsParserType.GetUShortField    PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetUShortFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetUShortFieldByNumber    PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                    LONG
Length                                    LONG
U                                         USHORT
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN 0
  END
  IF Length < 2
    RETURN 0
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  U = SELF.ReadLeShort(SELF.DataQ.Payload,Offset)
  RETURN U

TpsParserType.GetLongField  PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetLongFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetLongFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                LONG
Length                                LONG
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN 0
  END
  IF Length < 4
    RETURN 0
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  RETURN SELF.ReadLeLong(SELF.DataQ.Payload,Offset)

TpsParserType.GetULongField PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetULongFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetULongFieldByNumber PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                LONG
Length                                LONG
U                                     ULONG
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN 0
  END
  IF Length < 4
    RETURN 0
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  U = SELF.ReadLeLong(SELF.DataQ.Payload,Offset)
  RETURN U

TpsParserType.GetRealField  PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetRealFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetRealFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                LONG
Length                                LONG
FloatValue                            GROUP
Bytes                                   STRING(4)
Value                                   SREAL,OVER(Bytes)
                                      END
DoubleValue                           GROUP
Bytes                                   STRING(8)
Value                                   REAL,OVER(Bytes)
                                      END
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN 0
  END
  GET(SELF.FieldQ,pFieldNo)
  GET(SELF.DataQ,SELF.CurrentRecord)
  CASE SELF.FieldQ.FieldType
    OF TpsFieldFloat
      IF Length < 4
        RETURN 0
      END
      FloatValue.Bytes = SELF.DataQ.Payload[Offset + 1 : Offset + 4]
      RETURN FloatValue.Value
    OF TpsFieldDouble
      IF Length < 8
        RETURN 0
      END
      DoubleValue.Bytes = SELF.DataQ.Payload[Offset + 1 : Offset + 8]
      RETURN DoubleValue.Value
    ELSE
      RETURN 0
  END

TpsParserType.GetDecimalField   PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetDecimalFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetDecimalFieldByNumber   PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                    LONG
Length                                    LONG
I                                         LONG
B                                         LONG
Digits                                    STRING(TpsNameMax)
Out                                       STRING(TpsNameMax)
DigitLen                                  LONG
DecimalPos                                LONG
StartPos                                  LONG
SignChar                                  STRING(1)
  CODE
  CLEAR(Digits)
  CLEAR(Out)
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN ''
  END
  GET(SELF.FieldQ,pFieldNo)
  GET(SELF.DataQ,SELF.CurrentRecord)
  IF SELF.FieldQ.FieldType <> TpsFieldBcd
    RETURN ''
  END
  DigitLen = 0
  LOOP I = 0 TO Length - 1
    B = SELF.ReadByte(SELF.DataQ.Payload,Offset + I)
    IF DigitLen + 2 <= SIZE(Digits)
      DigitLen += 1
      Digits[DigitLen] = CHOOSE(BSHIFT(B,-4) < 10,CHR(48 + BSHIFT(B,-4)),CHR(55 + BSHIFT(B,-4)))
      DigitLen += 1
      Digits[DigitLen] = CHOOSE(BAND(B,0FH) < 10,CHR(48 + BAND(B,0FH)),CHR(55 + BAND(B,0FH)))
    END
  END
  IF DigitLen < 2
    RETURN ''
  END
  SignChar = Digits[1]
  StartPos = 2
  LOOP WHILE StartPos <= DigitLen AND Digits[StartPos] = '0'
    StartPos += 1
  END
  IF StartPos > DigitLen
    Out = '0'
  ELSE
    IF SELF.FieldQ.BcdDigitsAfterDecimal > 0
      DecimalPos = DigitLen - SELF.FieldQ.BcdDigitsAfterDecimal + 1
      IF DecimalPos < StartPos
        Out = '0.'
        LOOP I = DecimalPos TO StartPos - 1
          Out = CLIP(Out) & '0'
        END
        Out = CLIP(Out) & Digits[StartPos : DigitLen]
      ELSE
        Out = Digits[StartPos : DecimalPos - 1] & '.' & Digits[DecimalPos : DigitLen]
      END
    ELSE
      Out = Digits[StartPos : DigitLen]
    END
  END
  IF SignChar <> '0'
    RETURN '-' & CLIP(Out)
  END
  RETURN CLIP(Out)

TpsParserType.GetRawField   PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetRawFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetRawFieldByNumber   PROCEDURE(LONG pFieldNo,LONG pDimension)
Offset                                LONG
Length                                LONG
  CODE
  IF SELF.ResolveFieldValue(pFieldNo,pDimension,Offset,Length)
    RETURN ''
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  RETURN SELF.Slice(SELF.DataQ.Payload,Offset,Length)

TpsParserType.GetDateField  PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetDateFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetDateFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension)
  CODE
  RETURN SELF.TpsDateToClarion(SELF.GetLongFieldByNumber(pFieldNo,pDimension))

TpsParserType.GetTimeField  PROCEDURE(STRING pFieldName,LONG pDimension)
  CODE
  RETURN SELF.GetTimeFieldByNumber(SELF.GetFieldNumber(pFieldName),pDimension)

TpsParserType.GetTimeFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension)
  CODE
  RETURN SELF.TpsTimeToClarion(SELF.GetLongFieldByNumber(pFieldNo,pDimension))

TpsParserType.GetMemoField  PROCEDURE(STRING pFieldName)
  CODE
  RETURN SELF.GetMemoFieldByNumber(SELF.GetFieldNumber(pFieldName))

TpsParserType.GetMemoFieldByNumber  PROCEDURE(LONG pFieldNo)
Owner                                 LONG
MemoIndex                             LONG
RawLen                                LONG
Out                                   STRING(TpsMemoStringMax)
  CODE
  CLEAR(Out)
  IF SELF.CurrentRecord < 1 OR SELF.CurrentRecord > RECORDS(SELF.DataQ) OR pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN ''
  END
  GET(SELF.FieldQ,pFieldNo)
  IF ~SELF.FieldQ.IsMemo
    RETURN ''
  END
  MemoIndex = SELF.FieldQ.MemoIndex
  GET(SELF.DataQ,SELF.CurrentRecord)
  Owner = SELF.DataQ.RecordNumber
  RawLen = SELF.CopyMemoRaw(Owner,MemoIndex,Out,SIZE(Out))
  IF RawLen < 1
    RETURN ''
  END
  RETURN Out[1 : RawLen]

TpsParserType.GetBlobField  PROCEDURE(STRING pFieldName,*BLOB pBlob)
  CODE
  RETURN SELF.GetBlobFieldByNumber(SELF.GetFieldNumber(pFieldName),pBlob)

TpsParserType.GetBlobFieldByNumber  PROCEDURE(LONG pFieldNo,*BLOB pBlob)
Owner                                 LONG
MemoIndex                             LONG
RawLen                                LONG
BlobLen                               LONG
Avail                                 LONG
Raw                                   &STRING
  CODE
  IF SELF.CurrentRecord < 1 OR SELF.CurrentRecord > RECORDS(SELF.DataQ) OR pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    pBlob{PROP:Size} = 0
    pBlob{PROP:Touched} = TRUE
    RETURN SELF.SetLastError(TpsErrBlobContext,'Invalid blob read context; current record=' & SELF.CurrentRecord & ' record queue count=' & RECORDS(SELF.DataQ) & ' field number=' & pFieldNo & ' field count=' & RECORDS(SELF.FieldQ))
  END
  GET(SELF.FieldQ,pFieldNo)
  IF ~(SELF.FieldQ.IsMemo OR SELF.FieldQ.IsBlob)
    pBlob{PROP:Size} = 0
    pBlob{PROP:Touched} = TRUE
    RETURN SELF.SetLastError(TpsErrBlobFieldType,'Field is not MEMO/BLOB; field number=' & pFieldNo & ' name=' & CLIP(SELF.FieldQ.ShortName) & ' type=' & CLIP(SELF.FieldQ.TypeName))
  END
  MemoIndex = SELF.FieldQ.MemoIndex
  GET(SELF.DataQ,SELF.CurrentRecord)
  Owner = SELF.DataQ.RecordNumber
  RawLen = SELF.MemoRawLength(Owner,MemoIndex)
  IF RawLen = 0
    pBlob{PROP:Size} = 0
    pBlob{PROP:Touched} = TRUE
    RETURN SELF.SetLastError(0,'')
  END
  Raw &= NEW(STRING(RawLen))
  RawLen = SELF.CopyMemoRaw(Owner,MemoIndex,Raw,RawLen)
  IF SELF.FieldQ.IsBlob
    IF RawLen < TpsBlobLenPrefix
      pBlob{PROP:Size} = RawLen
      IF RawLen > 0
        pBlob[0 : RawLen - 1] = Raw[1 : RawLen]
      END
      pBlob{PROP:Touched} = TRUE
      DISPOSE(Raw)
      RETURN SELF.SetLastError(0,'')
    END
    BlobLen = SELF.ReadLeLong(Raw,0)
    Avail = RawLen - TpsBlobLenPrefix
    IF BlobLen > Avail
      BlobLen = Avail
    END
    IF BlobLen < 0
      BlobLen = 0
    END
    pBlob{PROP:Size} = BlobLen
    IF BlobLen > 0
      pBlob[0 : BlobLen - 1] = Raw[TpsBlobLenPrefix + 1 : TpsBlobLenPrefix + BlobLen]
    END
  ELSE
    pBlob{PROP:Size} = RawLen
    IF RawLen > 0
      pBlob[0 : RawLen - 1] = Raw[1 : RawLen]
    END
  END
  pBlob{PROP:Touched} = TRUE
  DISPOSE(Raw)
  RETURN SELF.SetLastError(0,'')

TpsParserType.Construct PROCEDURE
  CODE
  SELF.Src &= NULL
  SELF.WorkPage &= NULL
  SELF.DataQ &= NEW(TpsDataQueue)
  SELF.MemoQ &= NEW(TpsMemoQueue)
  SELF.TableDefQ &= NEW(TpsTableDefQueue)
  SELF.TableNameQ &= NEW(TpsTableNameQueue)
  SELF.FieldQ &= NEW(TpsFieldQueue)

TpsParserType.Destruct  PROCEDURE
  CODE
  SELF.Kill()
  IF ~SELF.DataQ &= NULL
    DISPOSE(SELF.DataQ)
  END
  IF ~SELF.MemoQ &= NULL
    DISPOSE(SELF.MemoQ)
  END
  IF ~SELF.TableDefQ &= NULL
    DISPOSE(SELF.TableDefQ)
  END
  IF ~SELF.TableNameQ &= NULL
    DISPOSE(SELF.TableNameQ)
  END
  IF ~SELF.FieldQ &= NULL
    DISPOSE(SELF.FieldQ)
  END

TpsParserType.ResolveTableNumber    PROCEDURE(LONG pTableIndex)
I                                     LONG
Count                                 LONG
LastNo                                LONG
  CODE
  IF pTableIndex < 1
    RETURN 0
  END
  SORT(SELF.TableDefQ,+SELF.TableDefQ.TableNo,+SELF.TableDefQ.BlockNo)
  Count = 0
  LastNo = -1
  LOOP I = 1 TO RECORDS(SELF.TableDefQ)
    GET(SELF.TableDefQ,I)
    IF SELF.TableDefQ.TableNo <> LastNo
      Count += 1
      LastNo = SELF.TableDefQ.TableNo
      IF Count = pTableIndex
        RETURN SELF.TableDefQ.TableNo
      END
    END
  END
  RETURN 0

TpsParserType.GetTableNameByTableNumber PROCEDURE(LONG pTableNo)
I                                         LONG
ColonPos                                  LONG
  CODE
  IF pTableNo = 0
    RETURN ''
  END
  LOOP I = 1 TO RECORDS(SELF.TableNameQ)
    GET(SELF.TableNameQ,I)
    IF SELF.TableNameQ.TableNo = pTableNo
      RETURN CLIP(SELF.TableNameQ.Name)
    END
  END
  LOOP I = 1 TO RECORDS(SELF.FieldQ)
    GET(SELF.FieldQ,I)
    IF SELF.FieldQ.TableNo = pTableNo
      ColonPos = INSTRING(':',SELF.FieldQ.Name,1,1)
      IF ColonPos > 1
        RETURN SELF.FieldQ.Name[1 : ColonPos - 1]
      END
    END
  END
  RETURN ''

TpsParserType.LoadSource    PROCEDURE(STRING pFileName)
RawName                       STRING(TpsFileNameMax)
RawFile                       FILE,DRIVER('DOS'),PRE(RAW)
Record                          RECORD
Buffer                            STRING(TpsDosBufferMax)
                                END
                              END
FileSize                      LONG
ReadOfs                       LONG
Fetch                         LONG
  CODE
  RawName = pFileName
  RawFile{PROP:Name} = RawName
  OPEN(RawFile,TpsDosReadMode)
  IF ERRORCODE()
    RETURN SELF.SetLastError(TpsErrSourceOpen,'Could not open source file "' & CLIP(pFileName) & '", ERRORCODE=' & ERRORCODE())
  END
  FileSize = BYTES(RawFile)
  IF FileSize <= 0
    CLOSE(RawFile)
    RETURN SELF.SetLastError(TpsErrSourceEmpty,'Source file is empty: "' & CLIP(pFileName) & '"')
  END
  SELF.SrcLen = FileSize
  IF ~SELF.Src &= NULL
    DISPOSE(SELF.Src)
  END
  SELF.Src &= NEW(STRING(FileSize))
  ReadOfs = 0
  LOOP WHILE ReadOfs < FileSize
    Fetch = SIZE(RAW:Buffer)
    IF Fetch > FileSize - ReadOfs
      Fetch = FileSize - ReadOfs
    END
    GET(RawFile,ReadOfs + 1,Fetch)
    IF ERRORCODE()
      CLOSE(RawFile)
      RETURN SELF.SetLastError(TpsErrSourceRead,'Could not read source file "' & CLIP(pFileName) & '" at offset=' & ReadOfs & ' length=' & Fetch & ', ERRORCODE=' & ERRORCODE())
    END
    SELF.Src[ReadOfs + 1 : ReadOfs + Fetch] = RAW:Buffer[1 : Fetch]
    ReadOfs += Fetch
  END
  CLOSE(RawFile)
  RETURN 0

TpsParserType.DecryptSource PROCEDURE(STRING pOwner)
Key                           STRING(TpsKeySize)
I                             LONG
StartOfs                      LONG
EndOfs                        LONG
Length                        LONG
Result                        LONG
  CODE
  IF SELF.SrcLen < TpsHeaderDecryptLen
    RETURN SELF.SetLastError(TpsErrDecryptTooShort,'Encrypted TPS is too short to decrypt header; bytes=' & SELF.SrcLen)
  END
  CLEAR(Key)
  SELF.BuildOwnerKey(pOwner,Key)
  Result = SELF.DecryptRange(0,TpsHeaderDecryptLen,Key)
  IF Result <> 0
    RETURN SELF.SetLastError(TpsErrDecryptHeaderRange,'Encrypted TPS decrypt failed at header; offset=0 length=' & TpsHeaderDecryptLen)
  END
  IF SELF.ReadLeLong(SELF.Src,0) <> 0
    RETURN SELF.SetLastError(TpsErrDecryptHeaderMarker,'Encrypted TPS decrypt failed; bad owner/password or invalid header marker')
  END
  IF SELF.Slice(SELF.Src,TpsSignatureOffset,TpsSignatureLen) <> 'tOpS'
    RETURN SELF.SetLastError(TpsErrDecryptSignature,'Encrypted TPS decrypt failed; bad owner/password or invalid signature=' & SELF.Slice(SELF.Src,TpsSignatureOffset,TpsSignatureLen))
  END
  LOOP I = 0 TO ((TpsBlockEndTable - TpsBlockStartTable) / 4) - 1
    StartOfs = BSHIFT(SELF.ReadLeLong(SELF.Src,TpsBlockStartTable + (I * 4)),TpsBlockAddrShift) + TpsFirstPageOffset
    EndOfs   = BSHIFT(SELF.ReadLeLong(SELF.Src,TpsBlockEndTable + (I * 4)),TpsBlockAddrShift) + TpsFirstPageOffset
    IF ~((StartOfs = TpsFirstPageOffset AND EndOfs = TpsFirstPageOffset) OR StartOfs >= SELF.SrcLen)
      IF EndOfs > SELF.SrcLen
        EndOfs = SELF.SrcLen
      END
      Length = EndOfs - StartOfs
      IF Length > 0
        Result = SELF.DecryptRange(StartOfs,Length,Key)
        IF Result <> 0
          RETURN SELF.SetLastError(TpsErrDecryptDataRange,'Encrypted TPS decrypt failed; offset=' & StartOfs & ' length=' & Length)
        END
      END
    END
  END
  RETURN 0

TpsParserType.BuildOwnerKey PROCEDURE(STRING pOwner,*STRING pKey)
I                             LONG
Target                        LONG
Source                        LONG
OwnerLen                      LONG
KeyLen                        LONG
B                             LONG
  CODE
  CLEAR(pKey)
  OwnerLen = LEN(CLIP(pOwner))
  KeyLen = OwnerLen + 1
  LOOP I = 0 TO TpsKeySize - 1
    Target = BAND(I * TpsKeyByteStep,TpsKeyIndexMask)
    Source = SELF.ModLong(I + 1,KeyLen)
    IF Source < OwnerLen
      B = SELF.ReadByte(pOwner,Source)
    ELSE
      B = 0
    END
    pKey[Target + 1] = CHR(BAND(I + B,TpsByteMask))
  END
  SELF.ShuffleKey(pKey)
  SELF.ShuffleKey(pKey)

TpsParserType.ShuffleKey    PROCEDURE(*STRING pKey)
I                             LONG
WordA                         LONG
WordB                         LONG
PosB                          LONG
  CODE
  LOOP I = 0 TO TpsKeyWords - 1
    WordA = SELF.ReadLeLong(pKey,I * 4)
    PosB = BAND(WordA,0FH)
    WordB = SELF.ReadLeLong(pKey,PosB * 4)
    SELF.WriteLeLong(pKey,PosB * 4,WordA + BAND(WordA,WordB))
    SELF.WriteLeLong(pKey,I * 4,BOR(WordA,WordB) + WordA)
  END

TpsParserType.DecryptRange  PROCEDURE(LONG pOffset,LONG pLength,*STRING pKey)
Pos                           LONG
EndPos                        LONG
  CODE
  IF pOffset < 0 OR pLength < 0 OR pOffset + pLength > SELF.SrcLen
    RETURN SELF.SetLastError(TpsErrDecryptRangeBounds,'Decrypt range is outside source; offset=' & pOffset & ' length=' & pLength & ' source bytes=' & SELF.SrcLen)
  END
  IF BAND(pOffset,TpsKeySize - 1) <> 0
    RETURN SELF.SetLastError(TpsErrDecryptRangeAlign,'Decrypt range is not 64-byte aligned; offset=' & pOffset)
  END
  pLength -= BAND(pLength,TpsKeySize - 1)
  Pos = pOffset
  EndPos = pOffset + pLength
  LOOP WHILE Pos < EndPos
    SELF.DecryptBlock64(Pos,pKey)
    Pos += TpsKeySize
  END
  RETURN 0

TpsParserType.DecryptBlock64    PROCEDURE(LONG pOffset,*STRING pKey)
I                                 LONG
PosB                              LONG
KeyA                              LONG
NotKeyA                           LONG
Data1                             LONG
Data2                             LONG
  CODE
  I = TpsKeyWords - 1
  LOOP WHILE I >= 0
    KeyA = SELF.ReadLeLong(pKey,I * 4)
    PosB = BAND(KeyA,0FH)
    Data1 = SELF.ReadLeLong(SELF.Src,pOffset + (I * 4)) - KeyA
    Data2 = SELF.ReadLeLong(SELF.Src,pOffset + (PosB * 4)) - KeyA
    NotKeyA = BXOR(KeyA,TpsWordNotMask)
    SELF.WriteLeLong(SELF.Src,pOffset + (I * 4),BOR(BAND(Data1,KeyA),BAND(Data2,NotKeyA)))
    SELF.WriteLeLong(SELF.Src,pOffset + (PosB * 4),BOR(BAND(Data2,KeyA),BAND(Data1,NotKeyA)))
    I -= 1
  END

TpsParserType.ParseTps  PROCEDURE
HeaderSize                LONG
TopSpeed                  STRING(TpsSignatureLen)
I                         LONG
StartOfs                  LONG
EndOfs                    LONG
  CODE
  FREE(SELF.DataQ)
  FREE(SELF.MemoQ)
  FREE(SELF.TableDefQ)
  FREE(SELF.TableNameQ)
  FREE(SELF.FieldQ)
  IF SELF.SrcLen < TpsMinHeaderLen
    RETURN SELF.SetLastError(TpsErrHeaderTooShort,'Source is too short to be a TPS file; bytes=' & SELF.SrcLen)
  END
  IF SELF.ReadLeLong(SELF.Src,0) <> 0
    RETURN SELF.SetLastError(TpsErrHeaderMarker,'Invalid TPS header marker at offset=0; value=' & SELF.ReadLeLong(SELF.Src,0))
  END
  HeaderSize = SELF.ReadLeShort(SELF.Src,4)
  IF HeaderSize < TpsSignatureOffset + TpsSignatureLen OR HeaderSize > SELF.SrcLen
    RETURN SELF.SetLastError(TpsErrHeaderSize,'Invalid TPS header size=' & HeaderSize & '; source bytes=' & SELF.SrcLen)
  END
  TopSpeed = SELF.Slice(SELF.Src,TpsSignatureOffset,TpsSignatureLen)
  IF TopSpeed <> 'tOpS'
    RETURN SELF.SetLastError(TpsErrHeaderSignature,'Invalid TPS signature at offset=' & TpsSignatureOffset & '; value=' & TopSpeed)
  END
  LOOP I = 0 TO ((TpsBlockEndTable - TpsBlockStartTable) / 4) - 1
    StartOfs = BSHIFT(SELF.ReadLeLong(SELF.Src,TpsBlockStartTable + (I * 4)),TpsBlockAddrShift) + TpsFirstPageOffset
    EndOfs   = BSHIFT(SELF.ReadLeLong(SELF.Src,TpsBlockEndTable + (I * 4)),TpsBlockAddrShift) + TpsFirstPageOffset
    IF ~((StartOfs = TpsFirstPageOffset AND EndOfs = TpsFirstPageOffset) OR StartOfs >= SELF.SrcLen)
      SELF.ParseBlock(StartOfs,EndOfs)
    END
  END
  RETURN 0

TpsParserType.ParseBlock    PROCEDURE(LONG pStart,LONG pEnd)
Pos                           LONG
Addr                          LONG
PageSize                      LONG
  CODE
  Pos = pStart
  LOOP WHILE Pos < pEnd AND Pos < SELF.SrcLen - 6
    IF SELF.ReadLeLong(SELF.Src,Pos) = Pos
      PageSize = SELF.ReadLeShort(SELF.Src,Pos + 4)
      IF SELF.ParsePage(Pos) = 0
        IF SELF.IsCompletePage(Pos,PageSize)
          Pos += PageSize
        ELSE
          Pos += TpsPageScanStep
        END
      ELSE
        Pos += TpsPageScanStep
      END
    ELSE
      Pos += TpsPageScanStep
    END
    IF BAND(Pos,TpsPageScanStep - 1) <> 0
      Pos = BAND(Pos,TpsAlignMask) + TpsPageScanStep
    END
    LOOP WHILE Pos < pEnd AND Pos < SELF.SrcLen - 4
      Addr = SELF.ReadLeLong(SELF.Src,Pos)
      IF Addr = Pos
        BREAK
      END
      Pos += TpsPageScanStep
    END
  END

TpsParserType.IsCompletePage    PROCEDURE(LONG pPos,LONG pPageSize)
Ofs                               LONG
Addr                              LONG
  CODE
  IF pPageSize < TpsPageHeaderLen OR pPos + pPageSize > SELF.SrcLen
    RETURN FALSE
  END
  Ofs = TpsPageScanStep
  LOOP WHILE Ofs < pPageSize AND pPos + Ofs < SELF.SrcLen - 4
    Addr = SELF.ReadLeLong(SELF.Src,pPos + Ofs)
    IF Addr = pPos + Ofs
      RETURN FALSE
    END
    Ofs += TpsPageScanStep
  END
  RETURN TRUE

TpsParserType.ParsePage PROCEDURE(LONG pPos)
PageSize                  LONG
PageUncompressedSize      LONG
RecCount                  LONG
Flags                     LONG
CompressedStart           LONG
CompressedLen             LONG
  CODE
  PageSize = SELF.ReadLeShort(SELF.Src,pPos + 4)
  IF PageSize < TpsPageHeaderLen OR pPos + PageSize > SELF.SrcLen
    RETURN 1
  END
  PageUncompressedSize = SELF.ReadLeShort(SELF.Src,pPos + 6)
  RecCount   = SELF.ReadLeShort(SELF.Src,pPos + 10)
  Flags      = SELF.ReadByte(SELF.Src,pPos + 12)
  CompressedStart = pPos + TpsPageHeaderLen
  CompressedLen   = PageSize - TpsPageHeaderLen
  IF SELF.BuildWorkPage(CompressedStart,CompressedLen,PageSize,PageUncompressedSize,Flags)
    RETURN 1
  END
  IF Flags = 0
    RETURN SELF.ParseRecords(SELF.WorkPage,SELF.WorkPageLen,RecCount)
  END
  RETURN 0

TpsParserType.BuildWorkPage PROCEDURE(LONG pCompressedStart,LONG pCompressedLen,LONG pPageSize,LONG pPageSizeUncompressed,LONG pFlags)
MaxLen                        LONG
CompressedPos                 LONG
Skip                          LONG
ByteToRepeat                  LONG
Repeats                       LONG
I                             LONG
  CODE
  IF ~SELF.WorkPage &= NULL
    DISPOSE(SELF.WorkPage)
  END
  MaxLen = pPageSizeUncompressed + TpsWorkSlack
  IF MaxLen < pCompressedLen + TpsWorkSlack
    MaxLen = pCompressedLen + TpsWorkSlack
  END
  SELF.WorkPage &= NEW(STRING(MaxLen))
  SELF.WorkPageLen = 0
  IF pPageSize <> pPageSizeUncompressed AND pFlags = 0
    CompressedPos = 0
    LOOP WHILE CompressedPos < pCompressedLen - 1
      IF SELF.DecodeRleCount(pCompressedStart,pCompressedLen,CompressedPos,Skip)
        RETURN 1
      END
      IF Skip = 0
        RETURN 1
      END
      IF SELF.WorkPageLen + Skip > MaxLen OR CompressedPos + Skip > pCompressedLen
        RETURN 1
      END
      SELF.WorkPage[SELF.WorkPageLen + 1 : SELF.WorkPageLen + Skip] = SELF.Src[pCompressedStart + CompressedPos + 1 : pCompressedStart + CompressedPos + Skip]
      SELF.WorkPageLen += Skip
      CompressedPos += Skip
      IF ~(CompressedPos > pCompressedLen - 1)
        CompressedPos -= 1
        ByteToRepeat = SELF.ReadByte(SELF.Src,pCompressedStart + CompressedPos)
        CompressedPos += 1
        IF SELF.DecodeRleCount(pCompressedStart,pCompressedLen,CompressedPos,Repeats)
          RETURN 1
        END
        IF SELF.WorkPageLen + Repeats > MaxLen
          RETURN 1
        END
        LOOP I = 1 TO Repeats
          SELF.WorkPage[SELF.WorkPageLen + I] = CHR(ByteToRepeat)
        END
        SELF.WorkPageLen += Repeats
      END
    END
  ELSE
    IF pCompressedLen > MaxLen
      RETURN 1
    END
    SELF.WorkPage[1 : pCompressedLen] = SELF.Src[pCompressedStart + 1 : pCompressedStart + pCompressedLen]
    SELF.WorkPageLen = pCompressedLen
  END
  RETURN 0

TpsParserType.DecodeRleCount    PROCEDURE(LONG pCompressedStart,LONG pCompressedLen,*LONG pCompressedPos,*LONG pCount)
Msb                               LONG
Lsb                               LONG
Shift                             LONG
  CODE
  pCount = 0
  IF pCompressedPos >= pCompressedLen
    RETURN 1
  END
  pCount = SELF.ReadByte(SELF.Src,pCompressedStart + pCompressedPos)
  pCompressedPos += 1
  IF pCount > TpsRleExtended
    IF pCompressedPos >= pCompressedLen
      RETURN 1
    END
    Msb = SELF.ReadByte(SELF.Src,pCompressedStart + pCompressedPos)
    pCompressedPos += 1
    Lsb = BAND(pCount,TpsRleExtended)
    Shift = TpsRleBase * BAND(Msb,1)
    pCount = BAND(BSHIFT(Msb,7),0FF00H) + Lsb + Shift
  END
  RETURN 0

TpsParserType.ParseRecords  PROCEDURE(*STRING pData,LONG pLen,LONG pRecordCount)
Pos                           LONG
Count                         LONG
Flags                         LONG
RecordLen                     LONG
HeaderLen                     LONG
CopyLen                       LONG
NeedLen                       LONG
Prev                          &STRING
Cur                           &STRING
PrevLen                       LONG
PrevHdr                       LONG
  CODE
  Pos = 0
  Count = 0
  PrevLen = 0
  PrevHdr = 0
  Prev &= NULL
  LOOP WHILE Pos < pLen - 1 AND Count < pRecordCount
    Flags = SELF.ReadByte(pData,Pos)
    Pos += 1
    IF BAND(Flags,TpsFlagRecLen) <> 0
      IF Pos + 2 > pLen
        BREAK
      END
      RecordLen = SELF.ReadLeShort(pData,Pos)
      Pos += 2
    ELSE
      RecordLen = PrevLen
    END
    IF BAND(Flags,TpsFlagHeaderLen) <> 0
      IF Pos + 2 > pLen
        BREAK
      END
      HeaderLen = SELF.ReadLeShort(pData,Pos)
      Pos += 2
    ELSE
      HeaderLen = PrevHdr
    END
    CopyLen = BAND(Flags,TpsFlagCopyLen)
    IF CopyLen > 0 AND Prev &= NULL
      BREAK
    END
    IF RecordLen < 0 OR RecordLen < CopyLen OR HeaderLen < 0 OR Pos + (RecordLen - CopyLen) > pLen
      BREAK
    END
    IF RecordLen = 0
      IF ~Prev &= NULL
        DISPOSE(Prev)
      END
      Prev &= NULL
      PrevLen = 0
      PrevHdr = HeaderLen
      Count += 1
      CYCLE
    END
    Cur &= NEW(STRING(RecordLen))
    IF CopyLen > 0
      Cur[1 : CopyLen] = Prev[1 : CopyLen]
    END
    NeedLen = RecordLen - CopyLen
    IF NeedLen > 0
      Cur[CopyLen + 1 : RecordLen] = pData[Pos + 1 : Pos + NeedLen]
    END
    Pos += NeedLen
    SELF.ProcessRecord(Cur,RecordLen,HeaderLen)
    IF ~Prev &= NULL
      DISPOSE(Prev)
    END
    Prev &= Cur
    PrevLen = RecordLen
    PrevHdr = HeaderLen
    Count += 1
  END
  IF ~Prev &= NULL
    DISPOSE(Prev)
  END
  RETURN 0

TpsParserType.ProcessRecord PROCEDURE(*STRING pRecord,LONG pRecordLen,LONG pHeaderLen)
RecordType                    LONG
TableNo                       LONG
RecNo                         LONG
Owner                         LONG
MemoIndex                     LONG
Seq                           LONG
PayloadLen                    LONG
BlockNo                       LONG
NameLen                       LONG
  CODE
  IF pHeaderLen < 1 OR pRecordLen < pHeaderLen
    RETURN
  END
  IF SELF.ReadByte(pRecord,0) = TpsRecTableName
    IF pRecordLen >= pHeaderLen + 4
      CLEAR(SELF.TableNameQ)
      SELF.TableNameQ.TableNo = SELF.ReadBeLong(pRecord,pHeaderLen)
      NameLen = pHeaderLen - 1
      IF NameLen > SIZE(SELF.TableNameQ.Name)
        NameLen = SIZE(SELF.TableNameQ.Name)
      END
      IF NameLen > 0
        SELF.TableNameQ.Name[1 : NameLen] = pRecord[2 : NameLen + 1]
      END
      ADD(SELF.TableNameQ)
    END
    RETURN
  END
  IF pHeaderLen < 5
    RETURN
  END
  RecordType = SELF.ReadByte(pRecord,4)
  TableNo = SELF.ReadBeLong(pRecord,0)
  CASE RecordType
    OF TpsRecData
      IF pHeaderLen < 9
        RETURN
      END
      RecNo = SELF.ReadBeLong(pRecord,5)
      PayloadLen = pRecordLen - pHeaderLen
      IF PayloadLen > 0
        CLEAR(SELF.DataQ)
        SELF.DataQ.TableNo = TableNo
        SELF.DataQ.RecordNumber = RecNo
        IF PayloadLen > SIZE(SELF.DataQ.Payload)
          SELF.DataQ.PayloadLen = SIZE(SELF.DataQ.Payload)
        ELSE
          SELF.DataQ.PayloadLen = PayloadLen
        END
        SELF.DataQ.Payload[1 : SELF.DataQ.PayloadLen] = pRecord[pHeaderLen + 1 : pHeaderLen + SELF.DataQ.PayloadLen]
        ADD(SELF.DataQ)
      END
    OF TpsRecMemo
      IF pHeaderLen < 12
        RETURN
      END
      Owner = SELF.ReadBeLong(pRecord,5)
      MemoIndex = SELF.ReadByte(pRecord,9)
      Seq = SELF.ReadBeShort(pRecord,10)
      PayloadLen = pRecordLen - pHeaderLen
      IF PayloadLen > 0
        CLEAR(SELF.MemoQ)
        SELF.MemoQ.TableNo = TableNo
        SELF.MemoQ.Owner = Owner
        SELF.MemoQ.MemoIndex = MemoIndex
        SELF.MemoQ.Sequence = Seq
        IF PayloadLen > SIZE(SELF.MemoQ.Payload)
          SELF.MemoQ.DataLen = SIZE(SELF.MemoQ.Payload)
        ELSE
          SELF.MemoQ.DataLen = PayloadLen
        END
        SELF.MemoQ.Payload[1 : SELF.MemoQ.DataLen] = pRecord[pHeaderLen + 1 : pHeaderLen + SELF.MemoQ.DataLen]
        ADD(SELF.MemoQ)
      END
    OF TpsRecTableDef
      IF pHeaderLen < 7
        RETURN
      END
      BlockNo = SELF.ReadLeShort(pRecord,5)
      PayloadLen = pRecordLen - pHeaderLen
      IF PayloadLen > 0
        CLEAR(SELF.TableDefQ)
        SELF.TableDefQ.TableNo = TableNo
        SELF.TableDefQ.BlockNo = BlockNo
        IF PayloadLen > SIZE(SELF.TableDefQ.Payload)
          SELF.TableDefQ.DataLen = SIZE(SELF.TableDefQ.Payload)
        ELSE
          SELF.TableDefQ.DataLen = PayloadLen
        END
        SELF.TableDefQ.Payload[1 : SELF.TableDefQ.DataLen] = pRecord[pHeaderLen + 1 : pHeaderLen + SELF.TableDefQ.DataLen]
        ADD(SELF.TableDefQ)
      END
  END

TpsParserType.ParseTableLayout  PROCEDURE
I                                 LONG
Pos                               LONG
TotalLen                          LONG
Def                               &STRING
DriverVer                         LONG
RecordLen                         LONG
NrFields                          LONG
NrMemos                           LONG
NrIndexes                         LONG
FieldType                         LONG
FieldName                         STRING(TpsNameMax)
ShortName                         STRING(TpsNameMax)
Elements                          LONG
FieldLen                          LONG
FieldFlags                        LONG
IndexNo                           LONG
External                          STRING(TpsNameMax)
MemoName                          STRING(TpsNameMax)
MemoLen                           LONG
MemoFlags                         LONG
  CODE
  FREE(SELF.FieldQ)
  IF RECORDS(SELF.TableDefQ) = 0
    RETURN SELF.SetLastError(TpsErrTableDefMissing,'No table definitions found')
  END
  IF SELF.CurrentTable = 0
    SELF.CurrentTable = SELF.ResolveTableNumber(1)
  END
  SORT(SELF.TableDefQ,+SELF.TableDefQ.TableNo,+SELF.TableDefQ.BlockNo)
  TotalLen = 0
  LOOP I = 1 TO RECORDS(SELF.TableDefQ)
    GET(SELF.TableDefQ,I)
    IF SELF.TableDefQ.TableNo = SELF.CurrentTable
      TotalLen += SELF.TableDefQ.DataLen
    END
  END
  IF TotalLen < 10
    RETURN SELF.SetLastError(TpsErrTableDefIncomplete,'Incomplete table definition for table=' & SELF.CurrentTable & '; bytes=' & TotalLen)
  END
  Def &= NEW(STRING(TotalLen))
  Pos = 0
  LOOP I = 1 TO RECORDS(SELF.TableDefQ)
    GET(SELF.TableDefQ,I)
    IF SELF.TableDefQ.TableNo = SELF.CurrentTable
      Def[Pos + 1 : Pos + SELF.TableDefQ.DataLen] = SELF.TableDefQ.Payload[1 : SELF.TableDefQ.DataLen]
      Pos += SELF.TableDefQ.DataLen
    END
  END
  Pos = 0
  DriverVer = SELF.ReadLeShort(Def,Pos); Pos += 2
  RecordLen = SELF.ReadLeShort(Def,Pos); Pos += 2
  NrFields  = SELF.ReadLeShort(Def,Pos); Pos += 2
  NrMemos   = SELF.ReadLeShort(Def,Pos); Pos += 2
  NrIndexes = SELF.ReadLeShort(Def,Pos); Pos += 2
  LOOP I = 1 TO NrFields
    IF Pos + 3 > TotalLen
      DISPOSE(Def)
      RETURN SELF.SetLastError(TpsErrFieldDefHeader,'Incomplete field definition header; table=' & SELF.CurrentTable & ' field=' & I & ' offset=' & Pos & ' total=' & TotalLen)
    END
    FieldType = SELF.ReadByte(Def,Pos); Pos += 1
    CLEAR(FieldName)
    CLEAR(ShortName)
    CLEAR(SELF.FieldQ)
    SELF.FieldQ.TableNo = SELF.CurrentTable
    SELF.FieldQ.FieldType = FieldType
    SELF.FieldQ.Offset = SELF.ReadLeShort(Def,Pos); Pos += 2
    FieldName = SELF.ReadZeroString(Def,TotalLen,Pos)
    ShortName = SELF.StripTablePrefix(FieldName)
    IF Pos + 8 > TotalLen
      DISPOSE(Def)
      RETURN SELF.SetLastError(TpsErrFieldDefBody,'Incomplete field definition body; table=' & SELF.CurrentTable & ' field=' & I & ' name=' & CLIP(FieldName) & ' offset=' & Pos & ' total=' & TotalLen)
    END
    SELF.FieldQ.Name = FieldName
    SELF.FieldQ.ShortName = ShortName
    Elements = SELF.ReadLeShort(Def,Pos); Pos += 2
    FieldLen = SELF.ReadLeShort(Def,Pos); Pos += 2
    FieldFlags = SELF.ReadLeShort(Def,Pos); Pos += 2
    IndexNo = SELF.ReadLeShort(Def,Pos); Pos += 2
    IF Elements < 1
      Elements = 1
    END
    SELF.FieldQ.Elements = Elements
    SELF.FieldQ.Length = FieldLen
    CASE FieldType
      OF TpsFieldByte
        SELF.FieldQ.TypeName = 'BYTE'
      OF TpsFieldShort
        SELF.FieldQ.TypeName = 'SHORT'
      OF TpsFieldUShort
        SELF.FieldQ.TypeName = 'USHORT'
      OF TpsFieldDate
        SELF.FieldQ.TypeName = 'DATE'
      OF TpsFieldTime
        SELF.FieldQ.TypeName = 'TIME'
      OF TpsFieldLong
        SELF.FieldQ.TypeName = 'LONG'
      OF TpsFieldULong
        SELF.FieldQ.TypeName = 'ULONG'
      OF TpsFieldFloat
        SELF.FieldQ.TypeName = 'SREAL'
      OF TpsFieldDouble
        SELF.FieldQ.TypeName = 'REAL'
      OF TpsFieldBcd
        SELF.FieldQ.TypeName = 'DECIMAL'
      OF TpsFieldString
        SELF.FieldQ.TypeName = 'STRING'
      OF TpsFieldCString
        SELF.FieldQ.TypeName = 'CSTRING'
      OF TpsFieldPString
        SELF.FieldQ.TypeName = 'PSTRING'
      OF TpsFieldGroup
        SELF.FieldQ.TypeName = 'GROUP'
      ELSE
        SELF.FieldQ.TypeName = 'UNKNOWN'
    END
    CASE FieldType
      OF TpsFieldBcd
        IF Pos + 2 > TotalLen
          DISPOSE(Def)
          RETURN SELF.SetLastError(TpsErrBcdMetadata,'Incomplete BCD metadata; table=' & SELF.CurrentTable & ' field=' & I & ' name=' & CLIP(FieldName) & ' offset=' & Pos & ' total=' & TotalLen)
        END
        SELF.FieldQ.BcdDigitsAfterDecimal = SELF.ReadByte(Def,Pos); Pos += 1
        SELF.FieldQ.BcdLengthOfElement = SELF.ReadByte(Def,Pos); Pos += 1
    END
    ADD(SELF.FieldQ)
    CASE FieldType
      OF TpsFieldString OROF TpsFieldCString OROF TpsFieldPString
        IF Pos + 2 > TotalLen
          DISPOSE(Def)
          RETURN SELF.SetLastError(TpsErrStringMetadata,'Incomplete string metadata; table=' & SELF.CurrentTable & ' field=' & I & ' name=' & CLIP(FieldName) & ' offset=' & Pos & ' total=' & TotalLen)
        END
        Pos += 2
        FieldName = SELF.ReadZeroString(Def,TotalLen,Pos)
        IF LEN(CLIP(FieldName)) = 0
          IF Pos + 1 > TotalLen
            DISPOSE(Def)
            RETURN SELF.SetLastError(TpsErrStringExternalName,'Incomplete string external-name marker; table=' & SELF.CurrentTable & ' field=' & I & ' offset=' & Pos & ' total=' & TotalLen)
          END
          Pos += 1
        END
    END
  END
  LOOP I = 0 TO NrMemos - 1
    External = SELF.ReadZeroString(Def,TotalLen,Pos)
    IF LEN(CLIP(External)) = 0
      IF Pos + 1 > TotalLen
        DISPOSE(Def)
        RETURN SELF.SetLastError(TpsErrMemoExternalName,'Incomplete memo external-name marker; table=' & SELF.CurrentTable & ' memo=' & I & ' offset=' & Pos & ' total=' & TotalLen)
      END
      Pos += 1
    END
    MemoName = SELF.ReadZeroString(Def,TotalLen,Pos)
    IF Pos + 4 > TotalLen
      DISPOSE(Def)
      RETURN SELF.SetLastError(TpsErrMemoDef,'Incomplete memo definition; table=' & SELF.CurrentTable & ' memo=' & I & ' name=' & CLIP(MemoName) & ' offset=' & Pos & ' total=' & TotalLen)
    END
    MemoLen = SELF.ReadLeShort(Def,Pos); Pos += 2
    MemoFlags = SELF.ReadLeShort(Def,Pos); Pos += 2
    CLEAR(SELF.FieldQ)
    SELF.FieldQ.TableNo = SELF.CurrentTable
    SELF.FieldQ.Name = MemoName
    SELF.FieldQ.ShortName = SELF.StripTablePrefix(MemoName)
    SELF.FieldQ.FieldType = TpsMemoFieldType
    SELF.FieldQ.MemoIndex = I
    SELF.FieldQ.IsMemo = CHOOSE(BAND(MemoFlags,TpsBlobFlag) = 0,1,0)
    SELF.FieldQ.IsBlob = CHOOSE(BAND(MemoFlags,TpsBlobFlag) <> 0,1,0)
    SELF.FieldQ.TypeName = CHOOSE(SELF.FieldQ.IsBlob,'BLOB','MEMO')
    ADD(SELF.FieldQ)
  END
  DISPOSE(Def)
  IF RECORDS(SELF.FieldQ) = 0
    RETURN SELF.SetLastError(TpsErrFieldDefMissing,'No fields found in table definition; table=' & SELF.CurrentTable)
  END
  RETURN 0

TpsParserType.ReadZeroString    PROCEDURE(*STRING pData,LONG pLen,*LONG pPos)
Out                               STRING(TpsStringMax)
LenOut                            LONG
B                                 LONG
  CODE
  CLEAR(Out)
  LenOut = 0
  LOOP WHILE pPos < pLen
    B = SELF.ReadByte(pData,pPos)
    pPos += 1
    IF B = 0
      BREAK
    END
    IF LenOut < SIZE(Out)
      LenOut += 1
      Out[LenOut] = CHR(B)
    END
  END
  RETURN Out[1 : LenOut]

TpsParserType.StripTablePrefix  PROCEDURE(STRING pName)
Idx                               LONG
Tmp                               STRING(TpsNameMax)
  CODE
  Tmp = CLIP(pName)
  Idx = INSTRING(':',Tmp,1,1)
  IF Idx > 0
    RETURN Tmp[Idx + 1 : LEN(CLIP(Tmp))]
  END
  RETURN CLIP(Tmp)

TpsParserType.ResolveFieldValue PROCEDURE(LONG pFieldNo,LONG pDimension,*LONG pOffset,*LONG pLength)
ElementLen                        LONG
  CODE
  pOffset = 0
  pLength = 0
  IF SELF.CurrentRecord < 1 OR SELF.CurrentRecord > RECORDS(SELF.DataQ) OR pFieldNo < 1 OR pFieldNo > RECORDS(SELF.FieldQ)
    RETURN TRUE
  END
  GET(SELF.FieldQ,pFieldNo)
  IF SELF.FieldQ.IsMemo OR SELF.FieldQ.IsBlob
    RETURN TRUE
  END
  IF SELF.FieldQ.Elements > 1
    IF pDimension < 1 OR pDimension > SELF.FieldQ.Elements
      RETURN TRUE
    END
    ElementLen = SELF.FieldQ.Length / SELF.FieldQ.Elements
    pOffset = SELF.FieldQ.Offset + ((pDimension - 1) * ElementLen)
    pLength = ElementLen
  ELSE
    pOffset = SELF.FieldQ.Offset
    pLength = SELF.FieldQ.Length
  END
  GET(SELF.DataQ,SELF.CurrentRecord)
  IF pOffset + pLength > SELF.DataQ.PayloadLen
    RETURN TRUE
  END
  RETURN FALSE

TpsParserType.CompareMemoKey    PROCEDURE(LONG pIndex,LONG pOwner,LONG pMemoIndex)
  CODE
  GET(SELF.MemoQ,pIndex)
  IF SELF.MemoQ.TableNo < SELF.CurrentTable
    RETURN -1
  END
  IF SELF.MemoQ.TableNo > SELF.CurrentTable
    RETURN 1
  END
  IF SELF.MemoQ.Owner < pOwner
    RETURN -1
  END
  IF SELF.MemoQ.Owner > pOwner
    RETURN 1
  END
  IF SELF.MemoQ.MemoIndex < pMemoIndex
    RETURN -1
  END
  IF SELF.MemoQ.MemoIndex > pMemoIndex
    RETURN 1
  END
  RETURN 0

TpsParserType.FindFirstMemoChunk    PROCEDURE(LONG pOwner,LONG pMemoIndex)
First                                 LONG
Last                                  LONG
Mid                                   LONG
Cmp                                   LONG
Found                                 LONG
  CODE
  First = 1
  Last = RECORDS(SELF.MemoQ)
  Found = 0
  LOOP WHILE First <= Last
    Mid = First + ((Last - First) / 2)
    Cmp = SELF.CompareMemoKey(Mid,pOwner,pMemoIndex)
    IF Cmp < 0
      First = Mid + 1
    ELSE
      IF Cmp = 0
        Found = Mid
      END
      Last = Mid - 1
    END
  END
  RETURN Found

TpsParserType.MemoRawLength PROCEDURE(LONG pOwner,LONG pMemoIndex)
I                             LONG
RawLen                        LONG
  CODE
  RawLen = 0
  I = SELF.FindFirstMemoChunk(pOwner,pMemoIndex)
  LOOP WHILE I > 0 AND I <= RECORDS(SELF.MemoQ)
    GET(SELF.MemoQ,I)
    IF SELF.MemoQ.TableNo <> SELF.CurrentTable OR SELF.MemoQ.Owner <> pOwner OR SELF.MemoQ.MemoIndex <> pMemoIndex
      BREAK
    END
    RawLen += SELF.MemoQ.DataLen
    I += 1
  END
  RETURN RawLen

TpsParserType.CopyMemoRaw   PROCEDURE(LONG pOwner,LONG pMemoIndex,*STRING pRaw,LONG pMaxLen)
I                             LONG
RawLen                        LONG
CopyLen                       LONG
  CODE
  RawLen = 0
  IF pMaxLen < 1
    RETURN 0
  END
  I = SELF.FindFirstMemoChunk(pOwner,pMemoIndex)
  LOOP WHILE I > 0 AND I <= RECORDS(SELF.MemoQ)
    GET(SELF.MemoQ,I)
    IF SELF.MemoQ.TableNo <> SELF.CurrentTable OR SELF.MemoQ.Owner <> pOwner OR SELF.MemoQ.MemoIndex <> pMemoIndex
      BREAK
    END
    IF RawLen < pMaxLen
      CopyLen = SELF.MemoQ.DataLen
      IF CopyLen > pMaxLen - RawLen
        CopyLen = pMaxLen - RawLen
      END
      IF CopyLen > 0
        pRaw[RawLen + 1 : RawLen + CopyLen] = SELF.MemoQ.Payload[1 : CopyLen]
        RawLen += CopyLen
      END
    END
    I += 1
  END
  RETURN RawLen

TpsParserType.SetLastError  PROCEDURE(LONG pError,STRING pText)
  CODE
  IF pError = 0
    SELF.LastError = 0
    SELF.LastErrorText = ''
    RETURN 0
  END
  IF LEN(CLIP(pText)) <> 0
    SELF.LastErrorText = CLIP(pText)
  ELSIF SELF.LastError <> pError OR LEN(CLIP(SELF.LastErrorText)) = 0
    CASE pError
      OF 1
        SELF.LastErrorText = 'TPS parser error'
      ELSE
        SELF.LastErrorText = 'Clarion file error, ERRORCODE=' & pError
    END
  END
  SELF.LastError = pError
  RETURN pError

TpsParserType.ReadByte  PROCEDURE(*STRING pData,LONG pPos)
  CODE
  IF pPos < 0 OR pPos >= SIZE(pData)
    RETURN 0
  END
  RETURN VAL(pData[pPos + 1])

TpsParserType.ReadLeShort   PROCEDURE(*STRING pData,LONG pPos)
  CODE
  RETURN SELF.ReadByte(pData,pPos) + BSHIFT(SELF.ReadByte(pData,pPos + 1),8)

TpsParserType.ReadBeShort   PROCEDURE(*STRING pData,LONG pPos)
  CODE
  RETURN SELF.ReadByte(pData,pPos + 1) + BSHIFT(SELF.ReadByte(pData,pPos),8)

TpsParserType.ReadLeLong    PROCEDURE(*STRING pData,LONG pPos)
V                             LONG
  CODE
  V = SELF.ReadByte(pData,pPos) + BSHIFT(SELF.ReadByte(pData,pPos + 1),8) + BSHIFT(SELF.ReadByte(pData,pPos + 2),16) + BSHIFT(SELF.ReadByte(pData,pPos + 3),24)
  RETURN V

TpsParserType.ReadBeLong    PROCEDURE(*STRING pData,LONG pPos)
V                             LONG
  CODE
  V = SELF.ReadByte(pData,pPos + 3) + BSHIFT(SELF.ReadByte(pData,pPos + 2),8) + BSHIFT(SELF.ReadByte(pData,pPos + 1),16) + BSHIFT(SELF.ReadByte(pData,pPos),24)
  RETURN V

TpsParserType.WriteLeLong   PROCEDURE(*STRING pData,LONG pPos,LONG pValue)
  CODE
  IF pPos < 0 OR pPos + 4 > SIZE(pData)
    RETURN
  END
  pData[pPos + 1] = CHR(BAND(pValue,TpsByteMask))
  pData[pPos + 2] = CHR(BAND(BSHIFT(pValue,-8),TpsByteMask))
  pData[pPos + 3] = CHR(BAND(BSHIFT(pValue,-16),TpsByteMask))
  pData[pPos + 4] = CHR(BAND(BSHIFT(pValue,-24),TpsByteMask))

TpsParserType.ModLong   PROCEDURE(LONG pValue,LONG pDivisor)
Result                    LONG
  CODE
  IF pDivisor <= 0
    RETURN 0
  END
  Result = pValue
  LOOP WHILE Result >= pDivisor
    Result -= pDivisor
  END
  LOOP WHILE Result < 0
    Result += pDivisor
  END
  RETURN Result

TpsParserType.Slice PROCEDURE(*STRING pData,LONG pPos,LONG pLen)
Out                   STRING(TpsStringMax)
  CODE
  CLEAR(Out)
  IF pPos < 0 OR pLen < 1
    RETURN ''
  END
  IF pLen > SIZE(Out)
    pLen = SIZE(Out)
  END
  IF pPos + pLen > SIZE(pData)
    pLen = SIZE(pData) - pPos
  END
  IF pLen > 0
    Out[1 : pLen] = pData[pPos + 1 : pPos + pLen]
    RETURN Out[1 : pLen]
  END
  RETURN ''

TpsParserType.TpsDateToClarion  PROCEDURE(LONG pValue)
Y                                 LONG
M                                 LONG
D                                 LONG
  CODE
  IF pValue = 0
    RETURN 0
  END
  Y = BSHIFT(BAND(pValue,0FFFF0000H),-16)
  M = BSHIFT(BAND(pValue,0000FF00H),-8)
  D = BAND(pValue,000000FFH)
  IF Y < 1801 OR M < 1 OR M > 12 OR D < 1 OR D > 31
    RETURN 0
  END
  RETURN DATE(M,D,Y)

TpsParserType.TpsTimeToClarion  PROCEDURE(LONG pValue)
H                                 LONG
M                                 LONG
  CODE
  IF pValue = 0
    RETURN 0
  END
  M = BSHIFT(BAND(pValue,00FF0000H),-16)
  H = BSHIFT(BAND(pValue,7F000000H),-24)
  RETURN (H * 60 * 60 * 100) + (M * 60 * 100) + 1
