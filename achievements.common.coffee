{tr} = require 'i18n'
exports.list = -> [
	{id: 'bronze_medal', title: tr("Winning streak!"), description: tr("Win 5 games in a row"), icon: 'star', colour: '#840', type: 'streak', outcome: 1, count: 5},
	{id: 'silver_medal', title: tr("Amazing streak!"), description: tr("Win 10 games in a row"), icon: 'star', colour: '#ccc', type: 'streak', outcome: 1, count: 10},
	{id: 'gold_medal', title: tr("Unbeatable!"), description: tr("Win 15 games in a row"), icon: 'star', colour: '#D4AF37', type: 'streak', outcome: 1, count: 15},
	{id: 'epic_medal', title: tr("God-like!"), description: tr("Win 30 games in a row"), icon: 'star', colour: '#8913AE', type: 'streak', outcome: 1, count: 30},
	{id: 'bronze_loser', title: tr("You're shit at this!"), description: tr("Lose 5 games in a row"), icon: 'clown', colour: '#840', type: 'streak', outcome: 0, count: 5},
	{id: 'silver_loser', title: tr("Hey, at least you make the others look good!"), description: tr("Lose 10 games in a row"), icon: 'clown', colour: '#ccc', type: 'streak', outcome: 0, count: 10},
]

exports.find = (id) !->
	for achievement in exports.list()
		if achievement.id is id
			return achievement

exports.getNotificationText = (username, achievement) ->
	tr("%1 has completed an achievement: %2", username, achievement.title)

