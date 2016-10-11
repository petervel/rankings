App = require 'app'
Db = require 'db'
Comments = require 'comments'
{tr} = require 'i18n'
Texts = require 'texts'
Achievements = require 'achievements'
Timer = require 'timer'

DEFAULT_RANK = 1000
FACTOR = 64

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
		path: []
		pushText: Texts.getMatchCommentText pid1, pid2, outcome, epic

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

playerActive = (pid) -> +pid in App.memberIds()

MAX_TIME = 16*7*24*60*60 # 30 weeks
calculateScores = ->
	# init all players at default scores
	rs = {}
	for k, v of Db.shared.get('players') when playerActive(k)
		rs[k] = {ranking: DEFAULT_RANK, matches: 0}

	# go through all matches
	for id, m of Db.shared.get('matches')
		continue if m.deleted # match has been manually deleted
		continue if m.time < (App.time() - MAX_TIME) # too long ago
		continue if not playerActive(m.p1) or not playerActive(m.p2) # one of the players has left
		elo(rs[m.p1], rs[m.p2], m.outcome)
	rs

recalculate = !->
	log 'recalculating scores...'
	for u, v of calculateScores()
		Db.shared.merge 'players', u, v

getMatchesForPlayer = (pid, max) ->
	matches = []
	for id, match of Db.shared.get 'matches'
		if not match.deleted # and the match is not deleted
			if pid is match.p1 or pid is match.p2 # and the player was in this match
				matches.push match

	matches = matches.sort (a,b) -> b.time - a.time
	if max?
		matches = matches.slice(0, max)

	matches

checkAchievements = (pid) !->
	player = Db.shared.ref 'players', pid
	matches = getMatchesForPlayer pid

	for a in Achievements.list() when not player?.get('achievements', a.id) # skip the ones the player already has
		switch a.type
			when 'streak'
				streak = 0
				for match in matches
					if (match.p1 is pid and match.outcome is a.outcome) or (match.p2 is pid and match.outcome is 1 - a.outcome)
						streak++
						if streak is a.count
							log App.userName(pid), ': ', a.id
							completeAchievement pid, a
							break
					else
						# broke their streak
						break

completeAchievement = (pid, achievement) !->
	Db.shared.set 'players', pid, 'achievements', achievement.id, App.time()
	Comments.post
		s: 'achievement'
		u: pid
		aid: achievement.id
		path: []
		pushText: Achievements.getNotificationText App.userName(pid), achievement

# recalculate with a delay because currently the user is still a member
exports.onLeave = !-> Timer.set 1000, 'onJoin'
exports.onJoin = recalculate

exports.continuousRecalculation = !->
	recalculate()
	Timer.cancel 'continuousRecalculation'
	Timer.set (24*60*60*1000), 'continuousRecalculation'

exports.onUpgrade = !->
	exports.continuousRecalculation()

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
