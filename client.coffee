Page = require 'page'
Ui = require 'ui'
App = require 'app'
Db = require 'db'
Dom = require 'dom'
{tr} = require 'i18n'
Modal = require 'modal'
Server = require 'server'
Time = require 'time'
Comments = require 'comments'
Obs = require 'obs'
Form = require 'form'
Icon = require 'icon'

DEFAULT_RANK = 1000

exports.render = !->
	pageName = Page.state.get(0)
	return renderRankingsPage() if pageName is 'rankings'
	return renderAddMatch() if pageName is 'addMatch'
	return renderMatchPage(+pageName) if pageName
	renderOverview()

renderOverview = !->
	renderRankingsTop()
	renderAddMatchButton()
	renderMatches()

	Comments.enable
		messages:
			# the key is the `s` key.
			matchAdded: (c) -> tr("%1 added a match", App.userName(c.u))
			matchDeleted: (c) -> tr("%1 deleted a match", App.userName(c.u))

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
	Comments.inline
		store: ['matches', matchId, 'comments']

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
	Obs.observe !->
		return unless p1.get() and p2.get() and p1.get() isnt p2.get()

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

		epic = Obs.create(false)
		if Db.shared.get('config', 'enableEpic')
			Dom.div !->
				Dom.style display: "#{if result.get() is 0.5 then 'none' else 'inherit'}"
				Form.check
					text: Db.shared.get('config', 'epicDescription') ? tr("Epic win")
					onChange: (v) !-> epic.set v

		Dom.div !->
			Dom.style textAlign: 'center', margin: '20px'
			Ui.button tr("Add match"), !->
				# TODO: input validation
				if p1.get()? and p2.get()? and result.get()?
					Server.send 'addMatch', p1.get(), p2.get(), result.get(), (Db.shared.get('config', 'enableEpic') and epic.get())
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
	if expanded
		Dom.div !->
			Dom.style width: '100%', color: '#aaa', fontSize: '8pt', textAlign: 'center', padding: '5px', boxSizing: 'border-box'
			Time.deltaText match.get 'time'
			Dom.text tr(", added by %1", App.userName(match.get('addedBy')))

	Ui.item !->
		if not expanded
			Dom.onTap !-> Page.nav {0: match.key()}
		Dom.div !->
			Dom.style width: '90%', maxWidth: '600px', margin: 'auto', position: 'relative'

			Dom.div !->
				Dom.style Box: 'horizontal center'
				renderMatchContestant match.get('p1'), true, match.get('outcome'), match.get('epic')

				renderMatchContestant match.get('p2'), false, match.get('outcome'), match.get('epic')

renderMatchContestant = (p, left, outcome, epic) !->
	Dom.div !->
		Dom.style Flex: 1, Box: "#{if left then 'left' else 'right'} middle", justifyContent: 'space-between', padding: '5px', borderRadius: '3px', border: '2px solid transparent', overflow: 'hidden'
		winner = (left and outcome is 1) or (not left and outcome is 0)
		if outcome isnt 0.5 and winner
			Dom.style border: '1px solid #aaa', boxShadow: '#aaa 1px 1px 10px'

		renderAvatar = !->
			Dom.div !->
				Dom.style minWidth: '40px'
				Ui.avatar App.memberAvatar(p), {size: 40}

		renderName = !->
			Dom.span !->
				Dom.style margin: '0 10px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
				if winner then Dom.style fontWeight: 'bold'
				Dom.text App.userName p

		renderEpicIcon = !->
			Icon.render
				data: 'star'
				size: 20
				style: padding: '10px'
				color: App.colors().highlight

		if left
			Dom.div !->
				Dom.style Flex: 1, Box: 'left middle'
				renderAvatar()
				renderName()
			if Db.shared.get('config', 'enableEpic') and winner and epic then renderEpicIcon()
		else
			if Db.shared.get('config', 'enableEpic') and winner and epic then renderEpicIcon()
			Dom.div !->
				Dom.style Flex: 1, Box: 'right middle'
				renderName()
				renderAvatar()


renderRankingsTop = !->
	# render your scoring neighbors
	Ui.top !->
		# make a sorted array of players scores
		scoreArray = []
		for u, v of Db.shared.get('players')
			#t = Db.shared.get('players', u, 'ranking') ? DEFAULT_RANK
			scoreArray.push [u, v.ranking]
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

						if i is index
							Dom.style color: '#000'
						else
							Dom.style color: '#666'
						Dom.text (i+1) + ': ' + App.userName(scoreArray[i][0])
		Dom.div !->
			Dom.style padding: '8px', borderRadius: '2px', textAlign: 'center'
			Dom.addClass 'link'
			Dom.text tr("Show all rankings")
		Dom.onTap !->
			Page.nav {0:'rankings'}

renderRankingsPage = !->
	Db.shared.iterate 'players', (member) !->
		matchCount = Db.shared.get('players', member.key(), 'matches') ? 0
		Ui.item
			avatar: App.members.get(member.key(), 'avatar')
			content: App.members.get(member.key(), 'name')
			sub: tr("%1 match|es", matchCount)
			afterIcon: !-> renderPoints member.get('ranking'), 40
			onTap: !-> App.showMemberInfo member.key()
	, (member) -> -(Math.round(1000000*member.get('ranking'))) # apparently, it can't sort floats properly

renderPoints = (points, size, style=null) !->
	Dom.div !->
		roundedPoints = Math.round +points
		Dom.style
			background: '#0077CF'
			borderRadius: '50%'
			fontSize: (if points < 100 then (size*.5) else if roundedPoints < 1000 then (size*.4) else (size*.3)) + 'px'
			textAlign: 'center'
			width: size+'px'
			height: size+'px'
			color: 'white'
			Box: 'middle center'
		if style then Dom.style style
		Dom.text +roundedPoints


exports.renderSettings = !->
	Form.input
		name: '_title'
		text: tr("Rankings title (optional)")

	enableEpic = Obs.create(Db.shared?.get('config', 'enableEpic') ? false)
	Form.check
		name: 'enableEpic'
		value: Db.shared?.get('config', 'enableEpic') ? false
		text: tr("Enable epic wins")
		onChange: (v) !-> enableEpic.set v

	Obs.observe !->
		return if not enableEpic.get()
		Form.input
			name: 'epicDescription'
			value: Db.shared?.get('config', 'epicDescription') ? ''
			text: 'epic victory description'
