#include parens8.lua

parens8[[
(set explosion_colors (table 0 7 10 9 2 1))
(set gravity .4)

(set plane (table))
(set bombs (table))
(set t 0)
(set score 0)
(set speed 2)
(set particles (table))

(set distance2 (fn (a b) (+
    (^ (- a.x b.x) 2)
    (^ (- a.y b.y) 2))))
    
(set collides (fn (a b) 
    (and (and (< a.x (+ b.x b.width))
            (< b.x (+ a.x a.width)))
        (and (< a.y (+ b.y b.height))
            (< b.y (+ a.y a.height))))))
            
(set make_smoke 1)
(set make_explosion 1)
(set make_spark_cluster 1)
(set make_pop 1)
]]

parens8[[(capture_api (id

(set update_particles (fn ()
    (foreach particles (fn (particle) (env particle (seq
        (update particle)
        (set ttl (- ttl 1)
        (when (or (~= x (mid x -8 135))
                (~= y (mid y -8 135)))
            (del particles particle)))))))))
            
(set draw_particles (fn () (seq
	(set particles_fg (table))
	(foreach particles (fn (particle)
		(when (not particle.fg)
			(particle.draw particle)
			(add particles_fg particle)))))))

(set draw_particles_fg (fn ()
    (for ((particle) (all particles_fg))
        (particle.draw particle))))
        
"TODO"

(set _init (fn () (seq
    (set plane.x 56)
    (set plane.y 60)
    (set plane.vx 0)
    (set plane.vy 0)
    (set plane.width 16)
    (set plane.height 8)
    (set plane.lives 2)
    (set t 0)
    (set score 0)
    (set speed 2)
    (set particles (table))
    (set bombs (table))
    (init_clouds))))

    
(set _update(fn () (seq
    (when (== 0 (% t (flr (/ 30 speed)))) (make_bomb 130 (rnd 122)))
    (set speed (+ speed .001))
    (update_clouds clouds_bg 0 120 6 (* speed .5))
    (update_clouds clouds_fg -4 124 4 (* speed .75))
    (update_particles)
    (plane.update plane)
    (foreach bombs (fn (bomb) (bomb.update bomb)))
    (set t (+ 1 1)))))
    
(set _draw (fn () (seq
    (cls 12)
    (draw_sky)
    (draw_particles)
    (foreach bombs (fn (bomb) (bomb.draw bomb)))
    (plane.draw plane)
    (draw_particles_fg)
    (display_hud))))
))]]