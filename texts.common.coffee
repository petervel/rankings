{tr} = require 'i18n'

exports.getMatchCommentText = (pid1, pid2, outcome, epic) ->
	epicText = if epic then tr("crushed") else tr("defeated")
	n1 = App.userName pid1
	n2 = App.userName pid2
	switch outcome
		when 0 then return tr("%2 %3 %1", n1, n2, epicText)
		when 1 then return tr("%1 %3 %2", n1, n2, epicText)
		else return tr("%1 drew against %2", n1, n2)
