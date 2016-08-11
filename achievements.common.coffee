{tr} = require 'i18n'
exports.list = -> [
	{id: 'bronze_medal', name: tr("Winning streak!"), description: tr("Win 5 games in a row"), icon: 'star', colour: '#840', type: 'streak', outcome: 1, count: 5},
	{id: 'silver_medal', name: tr("Amazing streak!"), description: tr("Win 10 games in a row"), icon: 'star', colour: '#ccc', type: 'streak', outcome: 1, count: 10},
	{id: 'gold_medal', name: tr("Unbeatable!"), description: tr("Win 25 games in a row"), icon: 'star', colour: '#D4AF37', type: 'streak', outcome: 1, count: 25},
	{id: 'epic_medal', name: tr("God-like!"), description: tr("Win 50 games in a row"), icon: 'star', colour: '#8913AE', type: 'streak', outcome: 1, count: 50},
]

exports.find = (id) !->
	for achievement in exports.list()
		if achievement.id is id
			return achievement
