/* --------------------  rexx procedure  -------------------- *
 | Name:      tsotalk                                         |
 |                                                            |
 | Function:  Interactive ISPF dialog to send messages to     |
 |            other TSO users via the SEND command.           |
 |                                                            |
 | Syntax:    %tsotalk                                        |
 |                                                            |
 | Author:    Lionel B. Dyck                                  |
 |                                                            |
 | History:  (most recent on top)                             |
 |            2021/04/19 LBD - Creation                       |
 |                                                            |
 * ---------------------------------------------------------- */

Address ISPExec
loadinfo = loadispf()

do forever
'addpop'
'Display Panel(tsotalk)'
drc = rc
'rempop'
if drc > 0 then leave
  text = text''text1
  text = translate(text," ","'")
 Address TSO,
   'Send' "'"text''text1"'" 'User('talkuser') Now'
 end

x = dropispf(loadinfo)
exit 0

/* --------------------  rexx procedure  -------------------- *
 * Name:      LoadISPF                                        *
 *                                                            *
 * Function:  Load ISPF elements that are inline in the       *
 *            REXX source code.                               *
 *                                                            *
 * Syntax:    load_info = loadispf()                          *
 *            rc = dropispf(load_info)                        *
 *                                                            *
 *            The inline ISPF resources are limited to        *
 *            ISPF Messages, Panels, and Skeletons,           *
 *                 CLISTs and EXECs are also supported.       *
 *                                                            *
 *            The inline resources must start in column 1     *
 *            and use the following syntax:                   *
 *                                                            *
 *            >START    used to indicate the start of the     *
 *                      inline data                           *
 *                                                            *
 *            >END    - used to indicate the end of the       *
 *                      inline data                           *
 *                                                            *
 *            Each resource begins with a type record:        *
 *            >type name                                      *
 *               where type is CLIST, EXEC, MSG, PANEL, SKEL  *
 *                     name is the name of the element        *
 *                                                            *
 * Sample usage:                                              *
 *          -* rexx *-                                        *
 *          load_info = loadispf()                            *
 *          ... magic code happens here (your code) ...       *
 *          rc = dropispf(load_info)                          *
 *          exit                                              *
 *          >Start inline elements                            *
 *          >Panel panel1                                     *
 *          ...                                               *
 *          >Msg msg1                                         *
 *          ...                                               *
 *          >End of inline elements                           *
 *                                                            *
 * Returns:   the list of ddnames allocated for use along     *
 *            with the libdef's performed or altlib           *
 *                                                            *
 *            format is ddname libdef ddname libdef ...       *
 *                   libdef may be altlibc or altlibe         *
 *                   for altlib clist or altlib exec          *
 *                                                            *
 * Notes:     Entire routine must be included with REXX       *
 *            exec - inline with the code.                    *
 *                                                            *
 * Comments:  The entire rexx program is processed from the   *
 *            last record to the first to find the >START     *
 *            record at which point all records from that     *
 *            point on are processed until the >END           *
 *            statement or the end of the program is found.   *
 *                                                            *
 *            It is *strongly* suggested that the inline      *
 *            elements be at the very end of your code so     *
 *            that the search for them is faster.             *
 *                                                            *
 *            Inline ISPTLIB or ISPLLIB were not supported    *
 *            because the values for these would have to be   *
 *            in hex.                                         *
 *                                                            *
 * Author:    Lionel B. Dyck                                  *
 *                                                            *
 * History:                                                   *
 *            01/09/19 - Include DROPISPF routine             *
 *            08/29/17 - Fixup static values that were vars   *
 *            05/31/17 - Change default directory count       *
 *            12/09/16 - update for add_it routine            *
 *            05/10/16 - correction for clist and exec        *
 *            04/19/16 - bug correction                       *
 *            06/04/04 - Enhancements for speed               *
 *            08/05/02 - Creation                             *
 *                                                            *
 * ---------------------------------------------------------- *
 * Disclaimer: There is no warranty, either explicit or       *
 * implied with this code. Use it at your own risk as there   *
 * is no recourse from either the author or his employeer.    *
 * ---------------------------------------------------------- */
LoadISPF: Procedure

  parse value "" with null kmsg kpanel kskel first returns ,
    kclist kexec
/* ------------------------------------------------------- *
 * Find the InLine ISPF Elements and load them into a stem *
 * variable.                                               *
 *                                                         *
 * Elements keyword syntax:                                *
 * >START - start of inline data                           *
 * >CLIST name                                             *
 * >EXEC name                                              *
 * >MSG name                                               *
 * >PANEL name                                             *
 * >SKEL name                                              *
 * >END   - end of all inline data (optional if last)      *
 * ------------------------------------------------------- */
  last_line = sourceline()
  do i = last_line to 1 by -1
    line = sourceline(i)
    if translate(left(line,6)) = ">START " then leave
  end
  rec = 0
/* --------------------------------------------------- *
 * Flag types of ISPF resources by testing each record *
 * then add each record to the data. stem variable.    *
 * --------------------------------------------------- */
  do j = i+1 to last_line
    line = sourceline(j)
    if translate(left(line,5)) = ">END "   then leave
    if translate(left(line,7)) = ">CLIST " then kclist = 1
    if translate(left(line,6)) = ">EXEC "  then kexec  = 1
    if translate(left(line,5)) = ">MSG "   then kmsg   = 1
    if translate(left(line,7)) = ">PANEL " then kpanel = 1
    if translate(left(line,6)) = ">SKEL "  then kskel  = 1
    rec  = rec + 1
    data.rec = line
  end

/* ----------------------------------------------------- *
 * Now create the Library and Load the Member(s)         *
 * ----------------------------------------------------- */
  Address ISPExec
/* ----------------------------- *
 * Assign dynamic random ddnames *
 * ----------------------------- */
  clistdd = "lc"random(999)
  execdd  = "le"random(999)
  msgdd   = "lm"random(999)
  paneldd = "lp"random(999)
  skeldd  = "ls"random(999)

/* ---------------------------------------- *
 *  LmInit and LmOpen each resource library *
 * ---------------------------------------- */
  if kclist <> null then do
    call alloc_dd clistdd
    "Lminit dataid(clist) ddname("clistdd")"
    "LmOpen dataid("clist") Option(Output)"
    returns = strip(returns clistdd 'ALTLIBC')
  end
  if kexec <> null then do
    call alloc_dd execdd
    "Lminit dataid(exec) ddname("execdd")"
    "LmOpen dataid("exec") Option(Output)"
    returns = strip(returns execdd 'ALTLIBE')
  end
  if kmsg <> null then do
    call alloc_dd msgdd
    "Lminit dataid(msg) ddname("msgdd")"
    "LmOpen dataid("msg") Option(Output)"
    returns = strip(returns msgdd 'ISPMLIB')
  end
  if kpanel <> null then do
    call alloc_dd paneldd
    "Lminit dataid(panel) ddname("paneldd")"
    "LmOpen dataid("panel") Option(Output)"
    returns = strip(returns paneldd 'ISPPLIB')
  end
  if kskel <> null then do
    call alloc_dd skeldd
    "Lminit dataid(skel) ddname("skeldd")"
    "LmOpen dataid("skel") Option(Output)"
    returns = strip(returns skeldd 'ISPSLIB')
  end

/* ----------------------------------------------- *
 * Process all records in the data. stem variable. *
 * ----------------------------------------------- */
  do i = 1 to rec
    record = data.i
    recordu = translate(record)
    if left(recordu,5) = ">END " then leave
    if left(recordu,7) = ">CLIST " then do
      if first = 1 then call add_it
      type = "Clist"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,6) = ">EXEC " then do
      if first = 1 then call add_it
      type = "Exec"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,5) = ">MSG " then do
      if first = 1 then call add_it
      type = "Msg"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,7) = ">PANEL " then do
      if first = 1 then call add_it
      type = "Panel"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,6) = ">SKEL " then do
      if first = 1 then call add_it
      type = "Skel"
      first = 1
      parse value record with x name
      iterate
    end
   /* --------------------------------------------*
    * Put the record into the appropriate library *
    * based on the record type.                   *
    * ------------------------------------------- */
    Select
      When type = "Clist" then
      "LmPut dataid("clist") MODE(INVAR)" ,
        "DataLoc(record) DataLen(255)"
      When type = "Exec" then
      "LmPut dataid("exec") MODE(INVAR)" ,
        "DataLoc(record) DataLen(255)"
      When type = "Msg" then
      "LmPut dataid("msg") MODE(INVAR)" ,
        "DataLoc(record) DataLen(80)"
      When type = "Panel" then
      "LmPut dataid("panel") MODE(INVAR)" ,
        "DataLoc(record) DataLen(80)"
      When type = "Skel" then
      "LmPut dataid("skel") MODE(INVAR)" ,
        "DataLoc(record) DataLen(80)"
      Otherwise nop
    end
  end
  if type <> null then call add_it
/* ---------------------------------------------------- *
 * Processing completed - now lmfree the allocation and *
 * Libdef the library.                                  *
 * ---------------------------------------------------- */
  if kclist <> null then do
    Address TSO,
      "Altlib Act Application(Clist) File("clistdd")"
    "LmFree dataid("clist")"
  end
  if kexec <> null then do
    Address TSO,
      "Altlib Act Application(Exec) File("execdd")"
    "LmFree dataid("exec")"
  end
  if kmsg <> null then do
    "LmFree dataid("msg")"
    "Libdef ISPMlib Library ID("msgdd") Stack"
  end
  if kpanel <> null then do
    "Libdef ISPPlib Library ID("paneldd") Stack"
    "LmFree dataid("panel")"
  end
  if kskel <> null then do
    "Libdef ISPSlib Library ID("skeldd") Stack"
    "LmFree dataid("skel")"
  end
  return returns

/* --------------------------- *
 * Add the Member using LmmAdd *
 * based upon type of resource *
 * --------------------------- */
Add_It:
  Select
    When type = "Clist" then
    "LmmAdd dataid("clist") Member("name")"
    When type = "Exec" then
    "LmmAdd dataid("exec") Member("name")"
    When type = "Msg" then
    "LmmAdd dataid("msg") Member("name")"
    When type = "Panel" then
    "LmmAdd dataid("panel") Member("name")"
    When type = "Skel" then
    "LmmAdd dataid("skel") Member("name")"
    Otherwise nop
  end
  type = null
  return

/* ------------------------------ *
 * ALlocate the temp ispf library *
 * ------------------------------ */
Alloc_DD:
  arg dd
  Address TSO
  if pos(left(dd,2),"lc le") > 0 then
  "Alloc f("dd") unit(sysda) spa(5,5) dir(5)",
    "recfm(v b) lrecl(255) blksize(32760)"
  else
  "Alloc f("dd") unit(sysda) spa(5,5) dir(5)",
    "recfm(f b) lrecl(80) blksize(23440)"
  return

/* --------------------  rexx procedure  -------------------- *
 * Name:      DropISPF                                        *
 *                                                            *
 * Function:  Remove ISPF LIBDEF's and deactivate ALTLIB's    *
 *            that were created by the LoadISPF function.     *
 *                                                            *
 * Syntax:    rc = dropispf(load_info)                        *
 *                                                            *
 * Author:    Janko                                           *
 *                                                            *
 * History:                                                   *
 *            12/05/18 - Creation                             *
 * ---------------------------------------------------------- */
DropISPF: Procedure
  arg load_info
  Address ISPEXEC
  do until length(load_info) = 0
    parse value load_info with dd libd load_info
    if left(libd,6) = "ALTLIB" then do
      if libd = "ALTLIBC" then lib = "CLIST"
      else lib = "EXEC"
      Address TSO,
        "Altlib Deact Application("lib")"
    end
    else "libdef" libd
    address tso "free f("dd")"
  end
  return 0

/* Start of the inline ISPF Panel(s)
>Start
>Panel tsotalk
)Attr
 $ type(input ) hilite(uscore) caps(on)
 _ type(input ) hilite(uscore) caps(off)
 + type(text ) skip(on) intens(low)
)Body Window(63,6)
+Recipient Userid:$talkuser+
+
+Message Text:_Text                                         +
_Text1                                                      +
+                   (No quotes allowed)
+       Press%Enter+to Send or%F3+to Cancel and Exit
)Init
 &zwinttl = 'TSOTalk - Talk to another TSO User'
)Proc
 ver (&talkuser,nb)
 ver (&text,nb)
)End
>End */
