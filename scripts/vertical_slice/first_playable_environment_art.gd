class_name FirstPlayableEnvironmentArt
extends TriplePathEnvironmentArt

func _ready() -> void:
	# O fundo precisa permanecer atrás do blockout, da camada de ruínas e dos
	# lutadores procedurais. O script original usa z=1 para o protótipo com atlas.
	z_index = -10
	queue_redraw()
