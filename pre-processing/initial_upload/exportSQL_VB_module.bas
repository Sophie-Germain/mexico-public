Attribute VB_Name = "exportSQLBatch"
'exports to postgresql


Option Compare Database
Option Explicit

' exportSQL version 3.2-dev
' www.rot13.org/~dpavlin/projects.html#sql
'
' based on exportSQL version 2.0 from www.cynergi.net/prod/exportsql/
'
' (C) 1997-98 CYNERGI - www.cynergi.net, info@cynergi.net
' (C) Pedro Freire - pedro.freire@cynergi.net  (do not add to mailing lists without permission)
' (c) 2000-2001 Dobrica Pavlinusic <dpavlin@rot13.org> - added PostgreSQL support
'
' This code is provided free for anyone's use and is therefore without guarantee or support.
' This does NOT mean CYNERGI delegates its copyright to anyone using it! You may change the
' code in any way, as long as this notice remains on the code and CYNERGI is notified (if you
' publish the changes: if your changes/corrections prove valuable and are added to the code,
' you will be listed in a credit list on this file).
'
' You may NOT sell this as part of a non-free package:
' IF YOU HAVE PAID FOR THIS CODE, YOU HAVE BEEN ROBBED! CONTACT admin@cynergi.net!

' MODULE
'   "exportSQL"
'
' GOAL
'   Export all tables in a MS-Access database file to 2 text files:
'   one containing SQL instructions to delete the new tables to be created,
'   and the other with SQL instructions to create and insert data into
'   the new tables. The table structure and data will resemble as much as
'   possible the current Access database.
'
' HOW TO USE
'   Copy-and-paste this text file into an Access module and run the first
'   (and only public) function. in more detail, you:
'   * Open the Access .mdb file you wish to export
'   * in the default database objects window, click on "Modules", and then on "New"
'   * The code window that opens has some pre-written text (code). Delete it.
'   * Copy-and-paste this entire file to the code module window
'   * If you are using Microsoft Access 2000 you will have to make
'     one additional step: go into Tools/References and check following
'     component: Microsoft DAO Object 3.6 Library and uncheck Microsoft
'     ActiveX Data Objects Library
'   * You may hit the compile button (looks like 3 sheets of paper with an arrow on
'     top of them, pressing down on them), or select Debug, Compile Loaded Modules
'     from the top menu, just to make sure there are no errors, and that this code
'     works on your Access version (it works on Access'97 and should work on Access'95)
'   * Close the code module window - windows will prompt you to save the code:
'     answer "Yes", and when promped for a name for the module, type anything
'     (say, "MexportSQL")
'   The module is now part of your Access database. To run the export, you:
'   * Re-open the code module (by double-clicking on it, or clicking "Design"
'     with it selected). Move the cursor to where the first "Function" keyword appears.
'     Press F5 or select Run, Go/Continue from the top menu.
'   * Alternativelly, click on "Macros" on the database objects window,
'     and then on "New". On the macro window, select "RunCode" as the macro action,
'     and "exportSQL" as the function name, bellow. Save the macro similarly to the
'     module, and this time double-clicking on it, or clicking "Run" will run the export.
'
' BEFORE RUNNING THE EXPORT
'   Before running the export, be sure to check out the Export Options just bellow this
'   text, and change any according to your wishes and specs.
'
' TECH DATA
'   Public identifiers:
'   * Only one: "exportSQL", a function taking and returning no arguments. It runs the export.
'   Functionallity:
'   * Can export to mSQL v1, mSQL v2, MySQL or PostgreSQL recognised SQL statements
'   * Excellent respect for name conversion, namespace verification, type matching, etc.
'   * Detects default values "=Now()", "=Date()" and "=Time()" to create types like "TIMESTAMP"
'   * Fully configurable via private constants on top of code
'   * Exports two files: one for erasures, another for creations (useful when updating dbs)
'   * Generates compatibility warnings when necessary
'   * Code and generated files are paragraphed and easy to read
'   * Access text and memo fields can have any type of line termination: \n\r, \r\n, \n or \r
'   * Properly escapes text and memo fields, besides all types of binary fields
'   * Closes all open objects and files on error
'   * Known bugs / incomplete constructs are signalled with comments starting with "!!!!"
'   * Two alternatives on absent date/time type on mSQL: REAL or CHAR field
'   * Exports Primary key and Indexes for PostgreSQL
'   * Inserts Constrains as comments in SQL dump

' TODO:
'   + fix fields with non-valid characters (-, /, and friend)
'   + fix CR/LF in output
'   + fix boolean fields
'   + output of create table in separate file
'   - create index (FIX)

' Export Options - change at will

Private Const DB_ENGINE As String = "Pg"  ' USE ONLY "M1" (mSQL v1), "M2" (mSQL v2), "MY" (MySQL) or "Pg" (PostgreSQL)
Private Const DB_NAME As String = ""  ' Use empty string for current. Else use filename or DSN name of database to export
Private Const DB_CONNECT As String = ""  ' Used only if above string is not empty
Private Const MSQL_64kb_AVG As Long = 2048  ' ALWAYS < 65536 (to be consistent with MS Access). Set to max expected size of Access MEMO field (to preserve space in mSQL v1)
Private Const WS_REPLACEMENT As String = "_"  ' Use "" to simply eat whitespaces in identifiers (table and field names)
Private Const IDENT_MAX_SIZE As Integer = 19  ' Suggest 64. Max size of identifiers (table and field names)
Private Const PREFIX_ON_KEYWORD As String = "_"  ' Prefix to add to identifier, if it is a reserved word
Private Const SUFFIX_ON_KEYWORD As String = ""  ' Suffix to add to identifier, if it is a reserved word
Private Const PREFIX_ON_INDEX As String = "ix"  ' Prefix to add to index identifier, to make it unique (mSQL v2)
Private Const SUFFIX_ON_INDEX As String = ""  ' Suffix to add to index identifier, to make it unique (mSQL v2)
Private Const CREATE_SQL_FILE As String = ".\esql_create.txt" ' Use empty if open on #1. Will be overwritten if exists!
Private Const DEL_SQL_FILE As String = ".\esql_del.txt"  ' Use empty if open on #2. Will be overwritten if exists!
Private Const ADD_SQL_FILE As String = ".\esql_add.txt"  ' Use empty if open on #1. Will be overwritten if exists!
Private Const LINE_BREAK As String = "\n"  ' Try "<br>". String to replace line breaks in text fields
Private Const COMMENTS As Boolean = True  ' Dump comments into output file
Private Const DISPLAY_WARNINGS As Boolean = True  ' False to output the warnings to the files, only
Private Const DATE_AS_STR As Boolean = True  ' False to use real number data type for date, time and timestamp (in mSQL only)
Private Const PARA_INSERT_AFTER As Integer = 3  ' Field count after which print INSERTs different lines
Private Const INDENT_SIZE As Integer = 5  ' Number of spaces on indents

' Global var to store inter-funtion data
Private warnings As String  ' Not an option: do not set in any way
Private COMMENT_PREFIX As String
Private QUERY_SEPARATOR As String ' Terminator/separator of SQL queries (to instruct some monitor program to execute them)


' Primary Export Function

Sub exportSQL()
On Error GoTo exportSQL_error

    Dim cdb As Database
    Dim ctableix As Integer, ctablename As String
    If COMMENTS Then
        If DB_ENGINE = "Pg" Then
            COMMENT_PREFIX = "--"
            QUERY_SEPARATOR = ";"
        Else
            COMMENT_PREFIX = "#"
            QUERY_SEPARATOR = "\g"
        End If
    End If

    If DB_NAME = "" Then
        Set cdb = CurrentDb()
    Else
        Set cdb = OpenDatabase(DB_NAME, False, True, DB_CONNECT) ' Shared, read-only
    End If
    
    If CREATE_SQL_FILE <> "" Then Open CREATE_SQL_FILE For Output As #1
    If DEL_SQL_FILE <> "" Then Open DEL_SQL_FILE For Output As #2
    If ADD_SQL_FILE <> "" Then Open ADD_SQL_FILE For Output As #3

    DoCmd.Hourglass True

    If COMMENTS Then
        Dim convert_to As String
        If (Left$(DB_ENGINE, 2) = "MY") Then
            convert_to = "MySQL"
        ElseIf (DB_ENGINE = "Pg") Then
            convert_to = "PostgreSQL"
        Else
            convert_to = "mSQL"
        End If
        Print #1, COMMENT_PREFIX & " Exported from MS Access to " & convert_to
        Print #2, COMMENT_PREFIX & " Exported from MS Access to " & convert_to
        Print #3, COMMENT_PREFIX & " Exported from MS Access to " & convert_to
        Print #1, COMMENT_PREFIX & " (C) 1997-98 CYNERGI - www.cynergi.net, info@cynergi.net"
        Print #2, COMMENT_PREFIX & " (C) 1997-98 CYNERGI - www.cynergi.net, info@cynergi.net"
        Print #3, COMMENT_PREFIX & " (C) 1997-98 CYNERGI - www.cynergi.net, info@cynergi.net"
    End If

    'Go through the table definitions
    For ctableix = 0 To cdb.TableDefs.count - 1
    
        Dim cfieldix As Integer, cfieldname As String
        Dim fieldlst As String, sqlcode As String
        Dim primary_found As Boolean
        Dim crs As Recordset
    
        ' Let's take only the visible tables
        If (((cdb.TableDefs(ctableix).Attributes And DB_SYSTEMOBJECT) Or _
        (cdb.TableDefs(ctableix).Attributes And DB_HIDDENOBJECT))) = 0 Then
            
            ctablename = conv_name("" & cdb.TableDefs(ctableix).Name)
            
            Print #2,
            Print #2, "DROP TABLE " & ctablename & QUERY_SEPARATOR
            
            ' CREATE clause
            Print #1,
            Print #1, "CREATE TABLE " & ctablename
            Print #1, Space$(INDENT_SIZE) & "("
            
            warnings = ""
            fieldlst = ""
            primary_found = False
            
            ' loop thorugh each field in the table
            For cfieldix = 0 To cdb.TableDefs(ctableix).Fields.count - 1
                
                Dim typestr As String, fieldsz As Integer, dvstr As String
                Dim found_ix As Boolean, cindex, tmpindex As Index, cfield, tmpfield As Field
                
                ' if this is not the first iteration, add separators
                If fieldlst <> "" Then
                    fieldlst = fieldlst & ", "
                    Print #1, ","
                End If
                
                ' get field name
                cfieldname = conv_name("" & cdb.TableDefs(ctableix).Fields(cfieldix).Name)
                fieldlst = fieldlst & cfieldname
                
                ' translate types
                If DB_ENGINE = "M1" Or DB_ENGINE = "M2" Then
                    Select Case cdb.TableDefs(ctableix).Fields(cfieldix).Type
                        Case dbChar
                            typestr = "CHAR(" & cdb.TableDefs(ctableix).Fields(cfieldix).Size & ")"
                        Case dbText
                            fieldsz = cdb.TableDefs(ctableix).Fields(cfieldix).Size
                            If fieldsz = 0 Then fieldsz = 255
                            typestr = "CHAR(" & fieldsz & ")"
                        Case dbBoolean, dbByte, dbInteger, dbLong
                            typestr = "INT"
                        Case dbDouble, dbFloat, dbSingle
                            typestr = "REAL"
                        Case dbCurrency, dbDecimal, dbNumeric
                            typestr = "REAL"
                            warn "In new field '" & cfieldname & "', currency/BCD will be converted to REAL - there may be precision loss!", False
                        Case dbDate
                            typestr = IIf(DATE_AS_STR, "CHAR(19)", "REAL") ' use Access internal format: IEEE 64-bit (8-byte) FP
                            warn "In new field '" & cfieldname & "', date/time/timestamp will be converted to " & typestr & ".", False
                        Case dbTime
                            typestr = IIf(DATE_AS_STR, "CHAR(8)", "REAL") ' use Access internal format: IEEE 64-bit (8-byte) FP
                            warn "In new field '" & cfieldname & "', date/time/timestamp will be converted to " & typestr & ".", False
                        Case dbTimeStamp
                            typestr = IIf(DATE_AS_STR, "CHAR(19)", "REAL") ' use Access internal format: IEEE 64-bit (8-byte) FP
                            warn "In new field '" & cfieldname & "', date/time/timestamp will be converted to " & typestr & "." & IIf(DB_ENGINE = "M2", " Consider using pseudo field '_timestamp'.", ""), False
                        Case dbMemo
                            If DB_ENGINE = "M2" Then
                                typestr = "TEXT(" & MSQL_64kb_AVG & ")"
                            Else
                                typestr = "CHAR(" & MSQL_64kb_AVG & ")"
                                warn "In new field '" & cfieldname & "', dbMemo is not supported by mSQL v1 - fields larger than MSQL_64kb_AVG (" & MSQL_64kb_AVG & ") will not be accepted!", False
                            End If
                        Case dbBinary, dbVarBinary
                            typestr = "CHAR(255)"
                            warn "In new field '" & cfieldname & "', dbBinary and dbVarBinary are not supported by mSQL! - will use a text (CHAR(255)) field.", True
                        Case dbLongBinary
                            typestr = "CHAR(" & MSQL_64kb_AVG & ")"
                            warn "In new field '" & cfieldname & "', dbLongBinary is not supported by mSQL! - will use a text (CHAR(" & MSQL_64kb_AVG & ")) field.", True
                        Case Else
                            warn "In new field '" & cfieldname & "', dbBigInt and dbGUID are not currently supported!", True
                            Error 5  ' invalid Procedure Call
                    End Select
                ElseIf DB_ENGINE = "MY" Then
                    Select Case cdb.TableDefs(ctableix).Fields(cfieldix).Type
                        Case dbBinary
                            typestr = "TINYBLOB"
                        Case dbBoolean
                            typestr = "TINYINT"
                        Case dbByte
                            typestr = "TINYINT UNSIGNED"
                        Case dbChar
                            typestr = "CHAR(" & cdb.TableDefs(ctableix).Fields(cfieldix).Size & ")"
                        Case dbCurrency
                            typestr = "DECIMAL(20,4)"
                        Case dbDate
                            typestr = "DATETIME"
                        Case dbDecimal
                            typestr = "DECIMAL(20,4)"
                        Case dbDouble
                            typestr = "REAL"
                        Case dbFloat
                            typestr = "REAL"
                        Case dbInteger
                            typestr = "SMALLINT"
                        Case dbLong
                            typestr = "INT"
                        Case dbLongBinary
                            typestr = "LONGBLOB"
                        Case dbMemo
                            typestr = "LONGBLOB"  ' !!!!! MySQL bug! Replace by LONGTEXT when corrected!
                        Case dbNumeric
                            typestr = "DECIMAL(20,4)"
                        Case dbSingle
                            typestr = "FLOAT"
                        Case dbText
                            fieldsz = cdb.TableDefs(ctableix).Fields(cfieldix).Size
                            If fieldsz = 0 Then fieldsz = 255
                            typestr = "CHAR(" & fieldsz & ")"
                        Case dbTime
                            typestr = "TIME"
                        Case dbTimeStamp
                            typestr = "TIMESTAMP"
                        Case dbVarBinary
                            typestr = "TINYBLOB"
                        Case dbBigInt, dbGUID
                            warn "In new field '" & cfieldname & "', dbBigInt and dbGUID are not currently supported!", True
                            Error 5  ' invalid Procedure Call
                        Case Else
                            typestr = "LONGBLOB"
                    End Select
                ElseIf DB_ENGINE = "Pg" Then
                    Select Case cdb.TableDefs(ctableix).Fields(cfieldix).Type
                        Case dbBinary
                            typestr = "int2"
                        Case dbBoolean
                            typestr = "bool"
                        Case dbByte
                            typestr = "int2"
                        Case dbChar
                            typestr = "varchar(" & cdb.TableDefs(ctableix).Fields(cfieldix).Size & ")"
                        Case dbCurrency
                            typestr = "DECIMAL(20,4)"
                        Case dbDate
                            typestr = "TIMESTAMP"
                        Case dbDecimal
                            typestr = "DECIMAL(20,4)"
                        Case dbDouble
                            typestr = "float8"
                        Case dbFloat
                            typestr = "float4"
                        Case dbInteger
                            typestr = "int4"
                        Case dbLong
                            typestr = "int8"
                        Case dbLongBinary
                            typestr = "text"        ' hm?
                        Case dbMemo
                            typestr = "text"
                        Case dbNumeric
                            typestr = "DECIMAL(20,4)"
                        Case dbSingle
                            typestr = "float4"
                        Case dbText
                            fieldsz = cdb.TableDefs(ctableix).Fields(cfieldix).Size
                            If fieldsz = 0 Then fieldsz = 255
                            typestr = "varchar(" & fieldsz & ")"
                        Case dbTime
                            typestr = "TIME"
                        Case dbTimeStamp
                            typestr = "TIMESTAMP"
                        Case dbVarBinary
                            typestr = "text"        ' hm?
                        Case dbBigInt, dbGUID
                            warn "In new field '" & cfieldname & "', dbBigInt and dbGUID are not currently supported!", True
                            Error 5  ' invalid Procedure Call
                        Case Else
                            typestr = "text"
                    End Select
                Else
                    warn "unkown DB_ENGINE string " & DB_ENGINE, True
                    Error 5  ' invalid Procedure Call
                End If
                
                ' check not null and auto-increment properties
                If ((cdb.TableDefs(ctableix).Fields(cfieldix).Attributes And dbAutoIncrField) <> 0) Then
                    If Left$(DB_ENGINE, 2) = "MY" Then
                        typestr = typestr & " NOT NULL AUTO_INCREMENT"
                    ElseIf DB_ENGINE = "Pg" Then
                        typestr = " serial"
                    Else
                        typestr = typestr & " NOT NULL"
                        warn "In new field '" & cfieldname & "', mSQL does not support auto-increment fields! - they will be pure INTs." & IIf(DB_ENGINE = "M2", " Consider using pseudo field '_rowid' or SEQUENCEs.", ""), False
                    End If
                ElseIf cdb.TableDefs(ctableix).Fields(cfieldix).Required = True Then
                    typestr = typestr & " NOT NULL"
                End If
                    
                ' default value
                dvstr = cdb.TableDefs(ctableix).Fields(cfieldix).DefaultValue
                If dvstr <> "" Then
                    If Left$(DB_ENGINE, 2) <> "MY" And DB_ENGINE <> "Pg" Then
                        warn "In new field '" & cfieldname & "', mSQL does not support default values! - they won't be initialised.", False
                    ElseIf Left$(DB_ENGINE, 2) = "MY" And cdb.TableDefs(ctableix).Fields(cfieldix).Required = False Then
                        warn "In new field '" & cfieldname & "', MySQL needs NOT NULL to support default values! - it won't be set a default.", False
                    ElseIf Left$(dvstr, 1) = """" Then
                        typestr = typestr & " DEFAULT '" & conv_str(Mid$(dvstr, 2, Len(dvstr) - 2)) & "'"
                    ElseIf ((LCase(dvstr) = "now()" Or LCase(dvstr) = "date()" Or LCase(dvstr) = "time()") And _
                    (Left$(typestr, 5) = "DATE " Or Left$(typestr, 5) = "TIME " Or Left$(typestr, 9) = "DATETIME ")) Then
                        typestr = "TIMESTAMP " & Right$(typestr, Len(typestr) - InStr(typestr, " "))
                    ElseIf LCase(dvstr) = "no" Then
                        typestr = typestr & " DEFAULT 0"
                    ElseIf LCase(dvstr) = "yes" Then
                        typestr = typestr & " DEFAULT 1"
                    Else
                        typestr = typestr & " DEFAULT " & dvstr
                    End If
                End If
                
                ' add constrains
                Dim val_rule, val_text As String
                val_rule = cdb.TableDefs(ctableix).Fields(cfieldix).ValidationRule
                val_text = cdb.TableDefs(ctableix).Fields(cfieldix).ValidationText
                If DB_ENGINE = "Pg" And val_rule <> "" Then
                    typestr = typestr & COMMENT_PREFIX & " check ( " & val_rule & " ) " & COMMENT_PREFIX & " " & val_text
                    warn "Field '" & cfieldname & "' has constrain '" & val_rule & "' with text '" & val_text & "' which you have to convert manually (inserted as comment in SQL)", False
                End If

                ' check if primary key (for mSQL v1)
                If DB_ENGINE = "M1" Then
                    found_ix = False
                    For Each cindex In cdb.TableDefs(ctableix).Indexes
                        If cindex.Primary Then
                            For Each cfield In cindex.Fields
                                If cfield.Name = cdb.TableDefs(ctableix).Fields(cfieldix).Name Then
                                    found_ix = True
                                    Exit For
                                End If
                            Next cfield
                            If found_ix Then Exit For
                        End If
                    Next cindex
                    If found_ix Then
                        If primary_found Then
                            warn "On new table '" & ctablename & "', mSQL v1 does not support more than one PRIMARY KEY! Only first key was set.", False
                        Else
                            typestr = typestr & " PRIMARY KEY"
                            primary_found = True
                        End If
                    End If
                End If
                
                'print out field info
                Print #1, Space$(INDENT_SIZE) & cfieldname & Space$(IDENT_MAX_SIZE - Len(cfieldname) + 2) & typestr;
            
            Next cfieldix
                  
            ' terminate CREATE clause
            If DB_ENGINE = "M2" Then
                Print #1,
                Print #1, Space$(INDENT_SIZE) & ")" & QUERY_SEPARATOR
            End If
                  
            ' primary key and other index declaration
            If DB_ENGINE = "M2" Or Left$(DB_ENGINE, 2) = "MY" Or DB_ENGINE = "Pg" Then
                For Each cindex In cdb.TableDefs(ctableix).Indexes
                    sqlcode = ""
                    For Each cfield In cindex.Fields
                        sqlcode = sqlcode & IIf(sqlcode = "", "", ", ") & conv_name(cfield.Name)
                    Next cfield
                    If DB_ENGINE = "M2" Then
                        Print #1, "CREATE " & IIf(cindex.Unique, "UNIQUE ", "") & "INDEX " & _
                        conv_name(PREFIX_ON_INDEX & cindex.Name & SUFFIX_ON_INDEX) & " ON " & _
                        ctablename & " (" & sqlcode & ")" & QUERY_SEPARATOR
                    ElseIf DB_ENGINE = "Pg" Then
                        If cindex.Primary Then
                            Print #1, ","
                            Print #1, Space$(INDENT_SIZE) & "PRIMARY KEY (" & sqlcode & ")";
                        ElseIf cindex.Unique Then
                            ' Print #1, ","
                            ' Print #1, Space$(INDENT_SIZE) & "UNIQUE INDEX (" & sqlcode & ")";
                        Else
                            ' skip indexes which are part of primary key
                            primary_found = False
                            For Each tmpindex In cdb.TableDefs(ctableix).Indexes
                                If tmpindex.Primary Then
                                    For Each tmpfield In tmpindex.Fields
                                        If sqlcode = conv_name(tmpfield.Name) Then
                                            primary_found = True
                                            Exit For
                                        End If
                                    Next tmpfield
                                End If
                            Next tmpindex
                            If Not primary_found Then
                                If DB_ENGINE = "Pg" Then
                                    ' FIX: create index....
                                Else
                                    Print #1, ","
                                    Print #1, Space$(INDENT_SIZE) & "INDEX (" & sqlcode & ")";
                                End If
                            End If
                        End If

                    Else
                        Print #1, ","
                        Print #1, Space$(INDENT_SIZE) & IIf(cindex.Primary, "PRIMARY ", "") & "KEY (" & sqlcode & ")";
                    End If
                Next cindex
            End If
            
            ' terminate CREATE clause
            If DB_ENGINE <> "M2" Then
                Print #1,
                Print #1, Space$(INDENT_SIZE) & ")" & QUERY_SEPARATOR
            End If

            ' print any warnings bellow it
            If COMMENTS And warnings <> "" Then
                If DB_ENGINE = "M2" Then Print #1, COMMENT_PREFIX & " "
                Print #1, warnings
                warnings = ""
            End If
            
            Print #1,
            
            
            ' INSERT clause
            Set crs = cdb.OpenRecordset(cdb.TableDefs(ctableix).Name)
            If crs.RecordCount <> 0 Then
                
                ' loop thorugh each record in the table
                crs.MoveFirst
                Dim batchSize As Integer
                batchSize = 250
                Dim count As Long
                count = 0
                Do Until crs.EOF
                    
                    If count Mod batchSize = 0 Then
                        ' start paragraphing
                        sqlcode = "INSERT INTO " & ctablename
                        If crs.Fields.count > PARA_INSERT_AFTER Then
                            Print #3, sqlcode
                            If DB_ENGINE = "M1" Then Print #3, Space$(INDENT_SIZE) & "(" & fieldlst & ")"
                            Print #3, "VALUES "
                            sqlcode = Space$(INDENT_SIZE)
                        Else
                            If DB_ENGINE = "M1" Then sqlcode = sqlcode & " (" & fieldlst & ")"
                            sqlcode = sqlcode & " VALUES "
                        End If
                    End If
                    sqlcode = sqlcode & " ( "
                    
                    ' loop through each field in each record
                    For cfieldix = 0 To crs.Fields.count - 1
                        ' based on type, prepare the field value
                        If IsNull(crs.Fields(cfieldix).Value) Then
                            sqlcode = sqlcode & "NULL"
                        Else
                            Select Case crs.Fields(cfieldix).Type
                                Case dbBoolean
                                    If DB_ENGINE = "Pg" Then
                                        sqlcode = sqlcode & IIf(crs.Fields(cfieldix).Value = True, "'t'", "'f'")
                                    Else
                                        sqlcode = sqlcode & IIf(crs.Fields(cfieldix).Value = True, "1", "0")
                                    End If
                                Case dbChar, dbText, dbMemo
                                    sqlcode = sqlcode & "'" & conv_str(crs.Fields(cfieldix).Value) & "'"
                                    If ctablename = "CATLOCAL" Then
                                        If conv_str(crs.Fields(cfieldix).Value) = "BENITO JUAREZ LAMINA UNO" Then
                                            Dim g As Integer
                                            g = 10
                                        End If
                                    End If
                                Case dbDate, dbTimeStamp
                                    If Left$(DB_ENGINE, 2) = "MY" Or DATE_AS_STR Then
                                        sqlcode = sqlcode & "'" & Format(crs.Fields(cfieldix).Value, "YYYY-MM-DD HH:MM:SS") & "'"
                                    Else
                                        'print in Access internal format: IEEE 64-bit (8-byte) FP
                                        sqlcode = sqlcode & "'" & Format(crs.Fields(cfieldix).Value, "#.#########") & "'"
                                    End If
                                Case dbTime
                                    If Left$(DB_ENGINE, 2) = "MY" Or DATE_AS_STR Then
                                        sqlcode = sqlcode & "'" & Format(crs.Fields(cfieldix).Value, "HH:MM:SS") & "'"
                                    Else
                                        'print in Access internal format: IEEE 64-bit (8-byte) FP
                                        sqlcode = sqlcode & "'" & Format(crs.Fields(cfieldix).Value, "#.#########") & "'"
                                    End If
                                Case dbBinary, dbLongBinary, dbVarBinary
                                    sqlcode = sqlcode & "'" & conv_bin(crs.Fields(cfieldix).Value) & "'"
                                Case dbCurrency, dbDecimal, dbDouble, dbFloat, dbNumeric, dbSingle
                                    sqlcode = sqlcode & conv_float(crs.Fields(cfieldix).Value)
                                Case Else
                                    sqlcode = sqlcode & conv_str(crs.Fields(cfieldix).Value)
                            End Select
                        End If
                        
                        ' paragraph separators
                        If cfieldix < crs.Fields.count - 1 Then
                            sqlcode = sqlcode & ", "
                            If crs.Fields.count > PARA_INSERT_AFTER Then
                                Print #3, sqlcode
                                sqlcode = Space$(INDENT_SIZE)
                            End If
                        End If
                        
                    Next cfieldix
                    
                    count = count + 1
                                        
                    crs.MoveNext
                    If count Mod batchSize = 0 Then
                        sqlcode = sqlcode & IIf(crs.Fields.count > PARA_INSERT_AFTER, " )", ")") & QUERY_SEPARATOR
                        Print #3, sqlcode
                    Else
                        If Not (crs.EOF) Then
                            ' print out result and any warnings
                            sqlcode = sqlcode & IIf(crs.Fields.count > PARA_INSERT_AFTER, " )", ")") & ","
                            'QUERY_SEPARATOR
                            'Print #3, sqlcode
                            'If COMMENTS And warnings <> "" Then
                            '    Print #3, warnings
                            '    warnings = ""
                            'End If
                            'If crs.Fields.count > PARA_INSERT_AFTER Then Print #3,
                        Else
                            sqlcode = sqlcode & IIf(crs.Fields.count > PARA_INSERT_AFTER, " )", ")")
                        End If
                    End If
                    
                    
                Loop
                
                If count Mod batchSize <> 0 Then
                    sqlcode = sqlcode & QUERY_SEPARATOR
                    Print #3, sqlcode
                End If
            Else
                
                ' if there is no data on the table
                If COMMENTS Then Print #3, COMMENT_PREFIX & " This table has no data"
            
            End If
            
            crs.Close
            Set crs = Nothing
        
        End If  'print only unhidden tables
    count = 0
    Next ctableix
    
exportSQL_exit:
    Close #3
    Close #2
    Close #1
    
    cdb.Close
    Set cdb = Nothing

    DoCmd.Hourglass False

    Exit Sub

exportSQL_error:
    MsgBox Err.Description
    Resume exportSQL_exit

End Sub


Private Function conv_name(strname As String) As String
    Dim i As Integer, str As String

    ' replace inner spaces with WS_REPLACEMENT
    str = strname
    i = 1
    While i <= Len(str)
        Select Case Mid$(str, i, 1)
            Case " ", Chr$(9), Chr$(10), Chr$(13), "-", "/"  ' space, tab, newline, carriage return
                str = Left$(str, i - 1) & WS_REPLACEMENT & Right$(str, Len(str) - i)
                i = i + Len(WS_REPLACEMENT)
            Case Else
                i = i + 1
        End Select
    Wend
    ' restrict tablename to IDENT_MAX_SIZE chars, *after* eating spaces
    str = Left$(str, IDENT_MAX_SIZE)
    ' check for reserved words
    conv_name = str
    If Left$(DB_ENGINE, 2) = "MY" Then
        Select Case LCase$(str)
            Case "add", "all", "alter", "and", "as", "asc", "auto_increment", "between", _
            "bigint", "binary", "blob", "both", "by", "cascade", "char", "character", _
            "change", "check", "column", "columns", "create", "data", "datetime", "dec", _
            "decimal", "default", "delete", "desc", "describe", "distinct", "double", _
            "drop", "escaped", "enclosed", "explain", "fields", "float", "float4", _
            "float8", "foreign", "from", "for", "full", "grant", "group", "having", _
            "ignore", "in", "index", "infile", "insert", "int", "integer", "interval", _
            "int1", "int2", "int3", "int4", "int8", "into", "is", "key", "keys", _
            "leading", "like", "lines", "limit", "lock", "load", "long", "longblob", _
            "longtext", "match", "mediumblob", "mediumtext", "mediumint", "middleint", _
            "numeric", "not", "null", "on", "option", "optionally", "or", "order", _
            "outfile", "partial", "precision", "primary", "procedure", "privileges", _
            "read", "real", "references", "regexp", "repeat", "replace", "restrict", _
            "rlike", "select", "set", "show", "smallint", "sql_big_tables", _
            "sql_big_selects", "sql_select_limit", "straight_join", "table", "tables", _
            "terminated", "tinyblob", "tinytext", "tinyint", "trailing", "to", "unique", _
            "unlock", "unsigned", "update", "usage", "values", "varchar", "varying", _
            "with", "write", "where", "zerofill"
                conv_name = Left$(PREFIX_ON_KEYWORD & str & SUFFIX_ON_KEYWORD, IDENT_MAX_SIZE)
                If (str = conv_name) Then
                    warn "In identifier '" & strname & "', the new form '" & strname & _
                    "' is a reserved word, and PREFIX_ON_KEYWORD ('" & _
                    PREFIX_ON_KEYWORD & "') and SUFFIX_ON_KEYWORD ('" & SUFFIX_ON_KEYWORD & _
                    "') make it larger than IDENT_MAX_SIZE, and after cut it is the same as the original! " & _
                    "This is usually caused by a void or empty PREFIX_ON_KEYWORD.", True
                    Error 5  ' invalid Procedure Call
                End If
        End Select
    End If
End Function


Private Function conv_str(str As String) As String
    Dim i As Integer, nlstr As String, rstr As Variant
    
    nlstr = ""
    rstr = Null
    i = 1
    While i <= Len(str)
        Select Case Mid$(str, i, 1)
            Case Chr$(0)  ' ASCII NUL
                nlstr = ""
                rstr = "\0"
            Case Chr$(8)  ' backspace
                nlstr = ""
                rstr = "\b"
            Case Chr$(9)  ' tab
                nlstr = ""
                rstr = "\t"
            Case "'"
                nlstr = ""
                rstr = "''"
            Case "\"
                nlstr = ""
                rstr = "\\"
            Case Chr$(10), Chr$(13)  ' line feed and carriage return
                If nlstr <> "" And nlstr <> Mid$(str, i, 1) Then
                    ' there was a previous newline and this is its pair: eat it
                    rstr = ""
                    nlstr = ""
                Else
                    ' this is a fresh newline
                    rstr = LINE_BREAK
                    nlstr = Mid$(str, i, 1)
                End If
            Case Else
                nlstr = ""
        End Select
        If Not IsNull(rstr) Then
            str = Left$(str, i - 1) & rstr & Right$(str, Len(str) - i)
            i = i + Len(rstr)
            rstr = Null
        Else
            i = i + 1
        End If
    Wend
    conv_str = str
End Function


Private Function conv_bin(str As String) As String
    Dim i As Integer, rstr As String
    
    rstr = ""
    i = 1
    While i <= Len(str)
        Select Case Mid$(str, i, 1)
            Case Chr$(0)  ' ASCII NUL
                rstr = "\0"
            Case Chr$(8)  ' backspace
                rstr = "\b"
            Case Chr$(9)  ' tab
                rstr = "\t"
            Case "'"
                rstr = "''"
            Case "\"
                rstr = "\\"
            Case Chr$(10)  ' line feed
                rstr = "\n"
            Case Chr$(13)  ' carriage return
                rstr = "\r"
        End Select
        If rstr <> "" Then
            str = Left$(str, i - 1) & rstr & Right$(str, Len(str) - i)
            i = i + Len(rstr)
            rstr = ""
        Else
            i = i + 1
        End If
    Wend
    conv_bin = str
End Function

' This function is used to convert local setting of decimal , to .
Private Function conv_float(str As String) As String
    Dim i As Integer
    
    i = 1
    While i <= Len(str)
        If Mid$(str, i, 1) = "," Then
            str = Left$(str, i - 1) & "." & Right$(str, Len(str) - i)
        End If
        i = i + 1
    Wend
    conv_float = str
End Function


Private Sub warn(str As String, abortq As Boolean)
    If DISPLAY_WARNINGS Then MsgBox str, vbOKOnly Or vbExclamation, "Warning"
    warnings = warnings & COMMENT_PREFIX & " Warning: " & str & Chr$(13) & Chr$(10)
End Sub
























