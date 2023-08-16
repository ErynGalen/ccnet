;; Data types: uint, int, fixp, str, [...]
;; uint, int, fixp are 16 bits wide
;; unsized types (str, [...]) are preceded by a uint indicating their size

;; All messages implicitely have an id and a size (uint)


;; request/get a connection-local ID; this allows several players to share one connection
(RequestID)
(AssignID
 :local_id uint)


;; for all these messages, `local_id` is the source/destination ID in the connection. It is not unique globally,
;; it's unique in the specific connection of a player
;; local_id marked source means the message is emitted by a player
;; local_id marked destination means the message is emitted by the server

(Join
 :local_id uint ;; source
 :world_name str)

;; `global_id` aren't actually global, they are only unique in the specific world they were created for
(AssignGlobalID
 :local_id uint ;; destination
 :global_id uint)

(PlayerInWorld ;; informs the destination player of another player in the room they're in
 :local_id uint ;; destination
 :global_id uint ;; other player
 :is_new bool
 :player_name str)

(PlayerUpdate
 :local_id uint ;; destination/source
 :global_id uint ;; player being updated (ignored and set appropriately by the server)
 :data [...])
