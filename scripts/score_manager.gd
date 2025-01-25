extends Node

# Meilleur score stocké dans cet autoload
var best_score: int = 0

# Met à jour le meilleur score si le nouveau score est meilleur
func update_score(new_score: int):
	if new_score > best_score:
		best_score = new_score

# Récupère le meilleur score
func get_best_score() -> int:
	return best_score
