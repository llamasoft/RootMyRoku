
Sub init()
    m.status = m.top.FindNode("status")
    m.status.font.size = 36

    m.spinner = m.top.FindNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.spinner.poster.observeField("loadStatus", "moveSpinner")
    setBusyState(False)

    m.top.ObserveField("text", "onTextUpdate")
    m.top.ObserveField("busy", "onBusyUpdate")
    m.top.SetFocus(True)
End Sub

Sub onTextUpdate(event As Object)
    event_type = Type(event)
    If event_type = "roSGNodeEvent" Then
        m.status.text = event.GetData()
    End If
End Sub

Sub moveSpinner(event As Object)
    ' Relocates the spinner to the bottom right corner.
    ' We don't have access to the spinner's dimensions until the image finishes loading.
    If m.spinner.poster.loadStatus = "ready" Then
        screen_right = 1280 - m.spinner.poster.bitmapWidth * 1.25
        screen_bottom = 720 - m.spinner.poster.bitmapHeight * 1.25
        m.spinner.translation = [screen_right, screen_bottom]
    End If
End Sub

Sub onBusyUpdate(event As Object)
    setBusyState(event.GetData())
End Sub

Sub setBusyState(busy As Boolean)
    If busy Then
        m.spinner.poster.rotation = 0
        m.spinner.visible = True
        m.spinner.control = "start"
    Else
        m.spinner.visible = False
        m.spinner.control = "stop"
    End If
End Sub

Sub onKeyEvent(key As String, pressed As Boolean) As Boolean
    ' Observe and note all witness key events.
    ' This is done so the main method can "observe" our lastKeyEvent field
    ' because the main method has no direct access to onKeyEvent calls.
    m.top.lastKeyEvent = { key: key, pressed: pressed }

    ' Pretend like we didn't handle the key so the event propagates.
    Return False
End Sub