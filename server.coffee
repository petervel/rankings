App = require 'app'
Db = require 'db'
Comments = require 'comments'
{tr} = require 'i18n'
Texts = require 'texts'
Achievements = require 'achievements'

DEFAULT_RANK = 1000
FACTOR = 32

exports.client_addMatch = (pid1, pid2, outcome, epic) !->
	if not outcome in [1, 0.5, 0] # win, draw, loss for p1
		log "User #{App.userId()} tried to add a match with outcome #{outcome}"
		return
	players = Db.shared.ref 'players'

	p1 = players.get(pid1) ? {}
	p2 = players.get(pid2) ? {}

	elo p1, p2, outcome

	players.merge pid1, p1
	players.merge pid2, p2

	matchId = Db.shared.incr 'matchId'
	Db.shared.set 'matches', matchId, {time: App.time(), addedBy: App.userId(), p1: pid1, p2: pid2, outcome: outcome, epic: epic}
	checkAchievements pid1
	checkAchievements pid2

	Comments.post
		s: 'matchAdded'
		u: App.userId()
		pid1: pid1
		pid2: pid2
		outcome: outcome
		epic: epic
		lowPrio: true
		path: [matchId]
		pushText: Texts.getCommentText pid1, pid2, outcome, epic

elo = (p1, p2, outcome) !->
	p1.ranking ?= DEFAULT_RANK
	p2.ranking ?= DEFAULT_RANK
	expected =  p1.ranking / (p1.ranking + p2.ranking)
	bet = FACTOR * (outcome - expected)
	p1.ranking += bet
	p2.ranking -= bet
	p1.matches ?= 0
	p2.matches ?= 0
	p1.matches++
	p2.matches++

calculateScores = ->
	# init all players at default scores
	rs = {}
	for k, v of Db.shared.get('players')
		rs[k] = {ranking: DEFAULT_RANK, matches: 0}

	# go through all matches
	for id, m of Db.shared.get('matches') when not m.deleted
		elo(rs[m.p1], rs[m.p2], m.outcome)
	rs

recalculate = !->
	for u, v of calculateScores()
		Db.shared.merge 'players', u, v

getMatchesForPlayer = (pid, max) ->
	matches = []
	Db.shared.iterate 'matches', ((match) !->
			#log matches.length, match.get('pid1')
			if not max? or matches.length < max # if we haven't reached the required amount
				if not match.get('deleted') # and the match is not deleted
					if pid in [match.get('p1'), match.get('p2')] # and the player was in this match
						matches.push match.get()
		)#, (match) -> 3 #-match.key() # newest matches first
	matches

checkAchievements = (pid) !->
	player = Db.shared.ref 'players', pid
	for a in Achievements.list() when not player?.get('achievements', a.id) # skip the ones the player already has
		switch a.type
			when 'streak'
				matches = getMatchesForPlayer pid
				log JSON.stringify matches
				streak = 0
				for match in matches
					if (match.p1 is pid and match.outcome is a.outcome) or (match.p2 is pid and match.outcome is 1 - a.outcome)
						streak++
						if streak is a.count
							log App.userName(pid), ': ', a.name
							player.set 'achievements', a.id, App.time()
							break

exports.onConfig = (config) !->
	log 'onConfig', config

	# empty description? then remove it entirely.
	if config.epicDescription is ''
		config.epicDescription = null

	Db.shared.set 'config', config

exports.client_deleteMatch = (matchId) !->
	match = Db.shared.get('matches', matchId)
	return if not match?
	return unless App.userIsAdmin() or App.userId() is match.addedBy

	# match exists and user is allowed to delete? carry on.
	Db.shared.set 'matches', matchId, 'deleted', true
	recalculate()

	Comments.post
		s: 'matchDeleted'
		u: App.userId()
		lowPrio: true
		path: ['match', matchId]
		pushText: tr("match deleted by %1", App.userName())
