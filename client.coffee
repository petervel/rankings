Page = require 'page'
Ui = require 'ui'
App = require 'app'
Db = require 'db'
Dom = require 'dom'
{tr} = require 'i18n'
Modal = require 'modal'
Server = require 'server'
Time = require 'time'

DEFAULT_RANK = 1000

exports.render = !->
	pageName = Page.state.get(0)
	return renderRankingsPage() if pageName is 'rankings'
	return renderAddMatch() if pageName is 'addMatch'
	return renderMatchPage(Page.state.get('matchId')) if pageName is 'match'
	renderOverview()

renderOverview = !->
	renderRankingsTop()
	renderAddMatchButton()
	renderMatches()

renderAddMatchButton = !->
	Dom.div !->
		Dom.style textAlign: 'center'
		Ui.button "Add match", !-> Page.nav {0: 'addMatch'}

renderMatchPage = (matchId) !->
	match = Db.shared.ref('matches', matchId)
	renderMatchDetails match, true
	if App.userIsAdmin() or App.userId() is match.get('addedBy')
		Dom.div !->
			Dom.style margin: '10px 0', textAlign: 'center'
			Ui.button tr("Delete this match"), !->
				Server.send 'deleteMatch', matchId
				Page.back()

renderAddMatch = !->
	p1 = Obs.create(App.userId()) # default to the user adding being one of the players
	p2 = Obs.create()
	result = Obs.create(1)

	Dom.div !->
		Dom.text tr("Players:")
	Ui.item !->
		Obs.observe !->
			if p1.get()
				Ui.avatar App.memberAvatar(p1.get())
				Dom.text App.userName(p1.get())
			else
				Ui.avatar(0, '#ccc')
		Dom.onTap !->
			renderPlayerSelector p2.peek(), p1
	Ui.item !->
		Obs.observe !->
			if p2.get()
				Ui.avatar App.memberAvatar(p2.get())
				Dom.text App.userName(p2.get())
			else
				Ui.avatar(0, '#ccc')
		Dom.onTap !->
			renderPlayerSelector p1.peek(), p2
	Dom.div !->
		Dom.style marginTop: '10px'
		Dom.text tr("Result:")
	Ui.item !->
		Obs.observe !->
			if result.get()?
				if result.get() isnt 0.5
					p = if result.get() is 1 then p1.get() else p2.get()
					Ui.avatar App.memberAvatar p
					Dom.text App.userName p
				else
					Ui.avatar(0, '#ccc')
					Dom.text tr("Draw")
			else
				Ui.avatar(0, '#ccc')
		Dom.onTap !->
			newResult = (result.peek() ? 0) + 0.5
			result.set (if newResult > 1 then 0 else newResult)
	Dom.div !->
		Dom.style textAlign: 'center', margin: '20px'
		Ui.button tr("Add match"), !->
			# TODO: check input validation
			if p1.get()? and p2.get()? and result.get()?
				Server.send 'addMatch', p1.get(), p2.get(), result.get()
				Page.back()

renderPlayerSelector = (unavailable, selected) !->
	chosen = Obs.create()
	Modal.confirm tr("Select player"), !->
			App.users.iterate (user) !->
				return if +user.key() is +unavailable
				Ui.item
					avatar: user.get('avatar')
					content: user.get('name')
					onTap: !->
						selected.set user.key()
						Modal.remove()
		, !-> selected.set chosen.get()

renderMatches = !->
	Dom.div !->
		Dom.style height: '20px'
	Db.shared.iterate 'matches', (match) !->
		if match.get 'deleted'
			Ui.item !->
				Dom.div !->
					Dom.style width: '100%', fontSize: '70%', color: '#aaa', textAlign: 'center', padding: '6px 0', fontStyle: 'italic'
					Dom.text tr("deleted match")
		else
			renderMatchDetails match, false
	, (match) -> -match.get 'time'


renderMatchDetails = (match, expanded) !->
	Ui.item !->
		if not expanded
			Dom.onTap !-> Page.nav {0:'match', 'matchId': match.key()}
		Dom.div !->
			Dom.style width: '100%', maxWidth: '600px', margin: 'auto', position: 'relative'
			Dom.div !->
				Dom.style Box: 'horizontal center'

				Dom.div !->
					Dom.style Flex: 1, Box: 'left middle'
					p1 = match.get 'p1'
					Ui.avatar App.memberAvatar(p1)

					Dom.span !->
						Dom.style margin: '0 10px'
						if match.get('outcome') is 1 then Dom.style fontWeight: 'bold'
						Dom.text App.userName p1

				Dom.div !->
					Dom.style Flex: 1, Box: 'right middle'
					p2 = match.get 'p2'
					Dom.span !->
						if match.get('outcome') is 0 then Dom.style fontWeight: 'bold'
						Dom.style margin: '0 10px'
						Dom.text App.userName p2
					Ui.avatar App.memberAvatar(p2)
			Dom.div !->
				Dom.style color: '#aaa', fontSize: '8pt', height: '10px', textAlign: 'center'
				Time.deltaText match.get 'time'
				if expanded
					Dom.text tr(", added by %1", App.userName(match.get('addedBy')))

renderRankingsTop = !->
	# render your scoring neighbors
	Ui.top !->
		# make a sorted array of players scores
		scoreArray = []
		for u, v of App.users.get()
			t = Db.shared.get('players', u, 'ranking') ? DEFAULT_RANK
			scoreArray.push [u, t]
		scoreArray.sort (a, b) -> b[1] - a[1]

		index = 0
		for s, i in scoreArray
			if App.userId() is (0|s[0])
				index = i
				break
		start = (Math.max(0, index-1))

		Dom.style padding: "12px 4px 0px"
		Dom.div !->
			Dom.style
				Box: 'middle'
				textAlign: 'center'
			for i in [start..(Math.min(start+2, scoreArray.length-1))]
				Dom.div !->
					Dom.style Flex: 1, overflow: 'hidden'
					Dom.div !->
						Dom.style Box: 'middle center'
						Ui.avatar App.memberAvatar(scoreArray[i][0])
						, style: marginRight: '6px'
						renderPoints(scoreArray[i][1], 40)
					Dom.div !->

						Dom.style overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: '4px'
					# Dom.span !->
						if i is index
							Dom.style color: '#000'
						else
							Dom.style color: '#666'
						Dom.text (i+1) + ': ' + App.userName(scoreArray[i][0])
					# Dom.br()
					# Dom.span !->
						# Dom.style color: if i is index then '#000' else '#666'
						# Dom.text '' + scoreArray[i][1]
		Dom.div !->
			Dom.style padding: '8px', borderRadius: '2px', textAlign: 'center'
			Dom.addClass 'link'
			Dom.text tr("Show all rankings")
		Dom.onTap !->
			Page.nav {0:'rankings'}

renderRankingsPage = !->
	App.members.iterate (member) !->
		score = Db.shared.get('players', member.key(), 'ranking') ? DEFAULT_RANK
		matchCount = Db.shared.get('players', member.key(), 'matches') ? 0
		Ui.item
			avatar: member.get('avatar')
			content: member.get('name')
			sub: tr("%1 match|es", matchCount)
			afterIcon: !->
				renderPoints(score, 40)
			onTap: !->
				App.showMemberInfo member.key()
	, (member) -> -(Db.shared.get('players', member.key(), 'ranking') ? DEFAULT_RANK)

renderPoints = (points, size, style=null) !->
	Dom.div !->
		Dom.style
			background: '#0077CF'
			borderRadius: '50%'
			fontSize: (if points < 100 then (size*.5) else if points < 1000 then (size*.4) else (size*.3)) + 'px'
			textAlign: 'center'
			width: size+'px'
			height: size+'px'
			color: 'white'
			Box: 'middle center'
		if style then Dom.style style
		Dom.text points
