;; Data types: number, string

;; All messages implicitely have an id (number)


;; request/get a connection-local ID; this allows several players to share one connection
(RequestID
 :player_name string)
(AssignID
 :local_id number)


;; for all these messages, `local_id` is the source/destination ID in the connection. It is not unique globally,
;; it's unique in the specific connection of a player
;; local_id marked source means the message is emitted by a player
;; local_id marked destination means the message is emitted by the server

(Join
 :local_id number ;; source
 :room_name string) ;; set to "" to leave the current room

;; `global_id` aren't actually global, they are only unique in the specific room they were created for
(AssignGlobalID
 :local_id number ;; destination
 :global_id number)

(PlayerInRoom ;; informs the destination player of another player in the room they're in
 :local_id number ;; destination
 :global_id number ;; other player
 :is_new bool
 :player_name string)

(PlayerLeft
  :local_id number ;; destination
  :global_id number) ;; player that has left

(PlayerUpdate
 :local_id number ;; destination/source
 :global_id number ;; player being updated (ignored and set appropriately by the server)
 :data ...)
;; :x number
;; :y number
;; :spr number
;; :flip_x bool
;; :flip_y bool
;; :djump number)
