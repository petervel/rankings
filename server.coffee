DEFAULT_RANK = 1000
FACTOR = 32

exports.client_addMatch = (pid1, pid2, outcome) !->
	if not outcome in [1, 0.5, 0] # win, draw, loss for p1
		log "User #{App.userId()} tried to add a game with outcome #{outcome}"
		return
	players = Db.shared.ref 'players'

	p1 = players.get(pid1) ? {}
	p2 = players.get(pid2) ? {}

	elo p1, p2, outcome

	players.merge pid1, p1
	players.merge pid2, p2

	count = Db.shared.incr 'matchId'
	Db.shared.set 'matches', count, {time: App.time(), addedBy: App.userId(), p1: pid1, p2: pid2, outcome: outcome}

elo = (p1, p2, outcome) !->
	p1.ranking ?= DEFAULT_RANK
	p2.ranking ?= DEFAULT_RANK
	expected =  p1.ranking / (p1.ranking + p2.ranking)
	bet = Math.round(FACTOR * (outcome - expected))
	p1.ranking += bet
	p2.ranking -= bet
	p1.matches ?= 0
	p2.matches ?= 0
	p1.matches++
	p2.matches++

exports.client_deleteMatch = (matchId) !->
	match = Db.shared.get('matches', matchId)
	return if not match?
	return unless App.userIsAdmin() or App.userId() is match.addedBy

	# match exists and user is allowed to delete? carry on.
	Db.shared.set 'matches', matchId, 'deleted', true
	recalculate()

recalculate = !->
	rs = {}
	for k, v of Db.shared.get('players')
		rs[k] = {ranking: DEFAULT_RANK, matches: 0}

	for id, m of Db.shared.get 'matches'
		continue if m.deleted
		elo(rs[m.p1], rs[m.p2], m.outcome)

	for u, v of rs
		Db.shared.merge 'players', u, v
