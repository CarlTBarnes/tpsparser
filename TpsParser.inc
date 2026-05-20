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

!Type declarations

TpsPayloadMax       EQUATE(32768)
TpsNameMax          EQUATE(128)
TpsTypeNameMax      EQUATE(32)

TpsDataQueue        QUEUE,TYPE
TableNo               LONG
RecordNumber          LONG
PayloadLen            LONG
Payload               STRING(TpsPayloadMax)
                    END

TpsMemoQueue        QUEUE,TYPE
TableNo               LONG
Owner                 LONG
MemoIndex             LONG
Sequence              LONG
DataLen               LONG
Payload               STRING(TpsPayloadMax)
                    END

TpsTableDefQueue    QUEUE,TYPE
TableNo               LONG
BlockNo               LONG
DataLen               LONG
Payload               STRING(TpsPayloadMax)
                    END

TpsTableNameQueue   QUEUE,TYPE
TableNo               LONG
Name                  STRING(TpsNameMax)
                    END

TpsFieldQueue       QUEUE,TYPE
TableNo               LONG
Name                  STRING(TpsNameMax)
ShortName             STRING(TpsNameMax)
FieldType             LONG
TypeName              STRING(TpsTypeNameMax)
Offset                LONG
Length                LONG
Elements              LONG
BcdDigitsAfterDecimal LONG
BcdLengthOfElement    LONG
IsMemo                BYTE
IsBlob                BYTE
MemoIndex             LONG
                    END

TpsParserType       CLASS,TYPE,MODULE('TpsParser'),LINK('TpsParser'),TYPE

! Initialization and cleanup
Init                  PROCEDURE(STRING pFileName),LONG
Init                  PROCEDURE(STRING pFileName,STRING pOwner),LONG
Kill                  PROCEDURE

! Error information
GetErrorCode          PROCEDURE,LONG
GetError              PROCEDURE,STRING

! Table selection and metadata
Tables                PROCEDURE,LONG
GetTableName          PROCEDURE(LONG pTableIndex),STRING
SetTable              PROCEDURE(LONG pTableIndex = 0),LONG,PROC

! Record navigation
Records               PROCEDURE,LONG
Get                   PROCEDURE(LONG pRecordNo),LONG,PROC
Set                   PROCEDURE(LONG pRecordNo = 0),LONG,PROC
Next                  PROCEDURE,BYTE

! Field metadata
Fields                PROCEDURE,LONG
GetFieldNameByNumber  PROCEDURE(LONG pFieldNo),STRING
GetFieldType          PROCEDURE(STRING pFieldName),STRING
GetFieldTypeByNumber  PROCEDURE(LONG pFieldNo),STRING
GetFieldDimension     PROCEDURE(STRING pFieldName),LONG
GetFieldDimensionByNumber PROCEDURE(LONG pFieldNo),LONG
GetFieldSize          PROCEDURE(STRING pFieldName),LONG
GetFieldSizeByNumber  PROCEDURE(LONG pFieldNo),LONG
GetFieldDecimals      PROCEDURE(STRING pFieldName),LONG
GetFieldDecimalsByNumber  PROCEDURE(LONG pFieldNo),LONG
GetFieldNumber        PROCEDURE(STRING pFieldName),LONG

! Generic field value
GetField              PROCEDURE(STRING pFieldName,LONG pDimension = 0),STRING
GetFieldByNumber      PROCEDURE(LONG pFieldNo,LONG pDimension = 0),STRING

! Typed scalar field values
GetStringField        PROCEDURE(STRING pFieldName,LONG pDimension = 0),STRING
GetStringFieldByNumber    PROCEDURE(LONG pFieldNo,LONG pDimension = 0),STRING
GetByteField          PROCEDURE(STRING pFieldName,LONG pDimension = 0),BYTE
GetByteFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension = 0),BYTE
GetShortField         PROCEDURE(STRING pFieldName,LONG pDimension = 0),SHORT
GetShortFieldByNumber PROCEDURE(LONG pFieldNo,LONG pDimension = 0),SHORT
GetUShortField        PROCEDURE(STRING pFieldName,LONG pDimension = 0),USHORT
GetUShortFieldByNumber    PROCEDURE(LONG pFieldNo,LONG pDimension = 0),USHORT
GetLongField          PROCEDURE(STRING pFieldName,LONG pDimension = 0),LONG
GetLongFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension = 0),LONG
GetULongField         PROCEDURE(STRING pFieldName,LONG pDimension = 0),ULONG
GetULongFieldByNumber PROCEDURE(LONG pFieldNo,LONG pDimension = 0),ULONG
GetRealField          PROCEDURE(STRING pFieldName,LONG pDimension = 0),REAL
GetRealFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension = 0),REAL
GetDecimalField       PROCEDURE(STRING pFieldName,LONG pDimension = 0),STRING
GetDecimalFieldByNumber   PROCEDURE(LONG pFieldNo,LONG pDimension = 0),STRING
GetRawField           PROCEDURE(STRING pFieldName,LONG pDimension = 0),STRING
GetRawFieldByNumber   PROCEDURE(LONG pFieldNo,LONG pDimension = 0),STRING
GetDateField          PROCEDURE(STRING pFieldName,LONG pDimension = 0),LONG
GetDateFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension = 0),LONG
GetTimeField          PROCEDURE(STRING pFieldName,LONG pDimension = 0),LONG
GetTimeFieldByNumber  PROCEDURE(LONG pFieldNo,LONG pDimension = 0),LONG

! MEMO and BLOB field values
GetMemoField          PROCEDURE(STRING pFieldName),STRING
GetMemoFieldByNumber  PROCEDURE(LONG pFieldNo),STRING
GetBlobField          PROCEDURE(STRING pFieldName,*BLOB pBlob),LONG,PROC
GetBlobFieldByNumber  PROCEDURE(LONG pFieldNo,*BLOB pBlob),LONG,PROC

! Private members
Src                   &STRING,PRIVATE
SrcLen                LONG,PRIVATE
WorkPage              &STRING,PRIVATE
WorkPageLen           LONG,PRIVATE
CurrentRecord         LONG,PRIVATE
CurrentTable          LONG,PRIVATE
LastError             LONG,PRIVATE
LastErrorText         STRING(512),PRIVATE
DataQ                 &TpsDataQueue,PRIVATE
MemoQ                 &TpsMemoQueue,PRIVATE
TableDefQ             &TpsTableDefQueue,PRIVATE
TableNameQ            &TpsTableNameQueue,PRIVATE
FieldQ                &TpsFieldQueue,PRIVATE
Construct             PROCEDURE,PRIVATE
Destruct              PROCEDURE,PRIVATE
ResolveTableNumber    PROCEDURE(LONG pTableIndex),LONG,PRIVATE
GetTableNameByTableNumber PROCEDURE(LONG pTableNo),STRING,PRIVATE
LoadSource            PROCEDURE(STRING pFileName),LONG,PRIVATE
DecryptSource         PROCEDURE(STRING pOwner),LONG,PRIVATE
BuildOwnerKey         PROCEDURE(STRING pOwner,*STRING pKey),PRIVATE
ShuffleKey            PROCEDURE(*STRING pKey),PRIVATE
DecryptRange          PROCEDURE(LONG pOffset,LONG pLength,*STRING pKey),LONG,PRIVATE
DecryptBlock64        PROCEDURE(LONG pOffset,*STRING pKey),PRIVATE
ParseTps              PROCEDURE,LONG,PRIVATE
ParseBlock            PROCEDURE(LONG pStart,LONG pEnd),PRIVATE
IsCompletePage        PROCEDURE(LONG pPos,LONG pPageSize),BYTE,PRIVATE
ParsePage             PROCEDURE(LONG pPos),LONG,PRIVATE
BuildWorkPage         PROCEDURE(LONG pCompressedStart,LONG pCompressedLen,LONG pPageSize,LONG pPageSizeUncompressed,LONG pFlags),LONG,PRIVATE
DecodeRleCount        PROCEDURE(LONG pCompressedStart,LONG pCompressedLen,*LONG pCompressedPos,*LONG pCount),LONG,PRIVATE
ParseRecords          PROCEDURE(*STRING pData,LONG pLen,LONG pRecordCount),LONG,PRIVATE
ProcessRecord         PROCEDURE(*STRING pRecord,LONG pRecordLen,LONG pHeaderLen),PRIVATE
ParseTableLayout      PROCEDURE,LONG,PRIVATE
ReadZeroString        PROCEDURE(*STRING pData,LONG pLen,*LONG pPos),STRING,PRIVATE
StripTablePrefix      PROCEDURE(STRING pName),STRING,PRIVATE
ResolveFieldValue     PROCEDURE(LONG pFieldNo,LONG pDimension,*LONG pOffset,*LONG pLength),BYTE,PRIVATE
CompareMemoKey        PROCEDURE(LONG pIndex,LONG pOwner,LONG pMemoIndex),LONG,PRIVATE
FindFirstMemoChunk    PROCEDURE(LONG pOwner,LONG pMemoIndex),LONG,PRIVATE
MemoRawLength         PROCEDURE(LONG pOwner,LONG pMemoIndex),LONG,PRIVATE
CopyMemoRaw           PROCEDURE(LONG pOwner,LONG pMemoIndex,*STRING pRaw,LONG pMaxLen),LONG,PRIVATE
SetLastError          PROCEDURE(LONG pError,STRING pText),LONG,PRIVATE
ReadByte              PROCEDURE(*STRING pData,LONG pPos),LONG,PRIVATE
ReadLeShort           PROCEDURE(*STRING pData,LONG pPos),LONG,PRIVATE
ReadBeShort           PROCEDURE(*STRING pData,LONG pPos),LONG,PRIVATE
ReadLeLong            PROCEDURE(*STRING pData,LONG pPos),LONG,PRIVATE
ReadBeLong            PROCEDURE(*STRING pData,LONG pPos),LONG,PRIVATE
WriteLeLong           PROCEDURE(*STRING pData,LONG pPos,LONG pValue),PRIVATE
ModLong               PROCEDURE(LONG pValue,LONG pDivisor),LONG,PRIVATE
Slice                 PROCEDURE(*STRING pData,LONG pPos,LONG pLen),STRING,PRIVATE
TpsDateToClarion      PROCEDURE(LONG pValue),LONG,PRIVATE
TpsTimeToClarion      PROCEDURE(LONG pValue),LONG,PRIVATE

DebugClassWindow      PROCEDURE()   !View the Class Queues and Variables to understand the class
DebugStringWindow     PROCEDURE( STRING StrValue, <STRING CapTxt>) !View a String in a Window in Hex or ASCII 
DebugStringWindow     PROCEDURE(*STRING StrValue, <STRING CapTxt>)
                    END

! GetErrorCode equates
TpsErrSourceOpen    EQUATE(1001)
TpsErrSourceEmpty   EQUATE(1002)
TpsErrSourceRead    EQUATE(1003)
TpsErrHeaderTooShort    EQUATE(1101)
TpsErrHeaderMarker  EQUATE(1102)
TpsErrHeaderSize    EQUATE(1103)
TpsErrHeaderSignature   EQUATE(1104)
TpsErrDecryptTooShort   EQUATE(1201)
TpsErrDecryptHeaderRange    EQUATE(1202)
TpsErrDecryptHeaderMarker   EQUATE(1203)
TpsErrDecryptSignature  EQUATE(1204)
TpsErrDecryptDataRange  EQUATE(1205)
TpsErrDecryptRangeBounds    EQUATE(1206)
TpsErrDecryptRangeAlign EQUATE(1207)
TpsErrTableIndex    EQUATE(1301)
TpsErrTableDefMissing   EQUATE(1401)
TpsErrTableDefIncomplete    EQUATE(1402)
TpsErrFieldDefHeader    EQUATE(1403)
TpsErrFieldDefBody  EQUATE(1404)
TpsErrBcdMetadata   EQUATE(1405)
TpsErrStringMetadata    EQUATE(1406)
TpsErrStringExternalName    EQUATE(1407)
TpsErrMemoExternalName  EQUATE(1408)
TpsErrMemoDef       EQUATE(1409)
TpsErrFieldDefMissing   EQUATE(1410)
TpsErrRecordIndex   EQUATE(1501)
TpsErrRecordNotFound    EQUATE(1502)
TpsErrBlobContext   EQUATE(1601)
TpsErrBlobFieldType EQUATE(1602)

