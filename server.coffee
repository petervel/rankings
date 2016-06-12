DEFAULT_RANK = 1000
FACTOR = 32

exports.client_addMatch = (p1, p2, outcome) !->
	players = Db.shared.ref 'players'
	r1 = players.peek(p1, 'ranking') ? DEFAULT_RANK
	r2 = players.peek(p2, 'ranking') ? DEFAULT_RANK

	expected =  r1 / (r1+r2)
	return if not outcome in [1, 0.5, 0] # win, draw, loss for p1

	bet = Math.round(FACTOR * (outcome - expected))

	players.set(p1, 'ranking', r1 + bet)
	players.set(p2, 'ranking', r2 - bet)
	players.incr p1, 'matches'
	players.incr p2, 'matches'

	count = Db.shared.incr 'matchId'
	Db.shared.set 'matches', count, {time: App.time(), addedBy: App.userId(), p1: p1, p2: p2, outcome: outcome}