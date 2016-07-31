{tr} = require 'i18n'
exports.list = -> [
	{id: 'bronze_medal', name: tr("Winning streak! (5 games)"), type: 'streak', outcome: 1, count: 5},
	{id: 'silver_medal', name: tr("Amazing streak! (10 games)"), type: 'streak', outcome: 1, count: 10},
	{id: 'gold_medal', name: tr("Unbeatable! (25 games)"), type: 'streak', outcome: 1, count: 25},
	{id: 'platinum_medal', name: tr("God-like! (50 games)"), type: 'streak', outcome: 1, count: 50,},
]
