(load "package://pr2eus/robot-interface.l")
(require :baxter "package://baxtereus//baxter.l")
(load "package://pr2eus/speak.l")
(ros::load-ros-manifest "control_msgs")
(ros::load-ros-manifest "baxter_core_msgs")

(defclass baxter-interface
  :super robot-interface
  :slots (gripper-sequence-id))
(defmethod baxter-interface
  (:init (&rest args)
   (prog1 (send-super :init :robot baxter-robot :joint-states-topic "/robot/joint_states")
     (send self :add-controller :larm-controller)
     (send self :add-controller :rarm-controller)
     (ros::advertise "/robot/end_effector/right_gripper/command" baxter_core_msgs::EndEffectorCommand 5) 
     (ros::advertise "/robot/end_effector/left_gripper/command" baxter_core_msgs::EndEffectorCommand 5) 
     (setq gripper-sequence-id 0)
     ))
  (:default-controller ()
   (append
    (send self :larm-controller)
    (send self :rarm-controller)))
  (:larm-controller ()
   (list
    (list
     (cons :controller-action "/robot/limb/left/follow_joint_trajectory")
     (cons :controller-state "/robot/limb/left/state")
     (cons :action-type control_msgs::FollowJointTrajectoryAction)
     (cons :joint-names (list "left_s0" "left_s1" "left_e0" "left_e1" "left_w0" "left_w1")))))
  (:rarm-controller ()
   (list
    (list
     (cons :controller-action "/robot/limb/right/follow_joint_trajectory")
     (cons :controller-state "/robot/limb/right/state")
     (cons :action-type control_msgs::FollowJointTrajectoryAction)
     (cons :joint-names (list "right_s0" "right_s1" "right_e0" "right_e1" "right_w0" "right_w1")))))
  (:close-head-camera ()
    (send self :close-camera "head_camera")
    )
  (:close-right-hand-camera ()
    (send self :close-camera "right_hand_camera")
    )
  (:close-left-hand-camera ()
    (send self :close-camera "left_hand_camera")
    )
  (:close-camera (camera)
    (let ((req (instance baxter_core_msgs::CloseCameraRequest :init)))
      (send req :name camera)
      (ros::service-call "/cameras/close" req)
      )
    )
  (:open-head-camera ()
    (send self :open-camera "head_camera")
    )
  (:open-right-hand-camera ()
    (send self :open-camera "right_hand_camera")
    )
  (:open-left-hand-camera ()
    (send self :open-camera "left_hand_camera")
    )
  (:open-camera (camera)
    (let ((camera-setting (instance baxter_core_msgs::CameraSettings :init :width 1280 :height 800 :fps 20))
          (req (instance baxter_core_msgs::OpenCameraRequest :init))
          )
      (send req :name camera)
      (send req :settings camera-setting)
      (ros::service-call "/cameras/open" req)
      )
    )
  (:get-cameras-list()
    (ros::wait-for-service "/cameras/list")
    (let ((req (instance baxter_core_msgs::ListCamerasRequest :init)) res)
      (setq res (ros::service-call "/cameras/list" req))
      (send res :cameras)
      ))

  (:clear-calib-grasp
   (&optional (arm :arms))
   (dolist (a (if (eq arm :arms) (list "left" "right") (list (if (eq arm :rarm) "right" "left"))))
     (send self :command-grasp baxter_core_msgs::EndEffectorCommand::*CMD_CLEAR_CALIBRATION* a)
     )
   )

  (:calib-grasp
   (&optional (arm :arms) &key ((:pos pos) 100))
   (dolist (a (if (eq arm :arms) (list "left" "right") (list (if (eq arm :rarm) "right" "left"))))
     (send self :command-grasp baxter_core_msgs::EndEffectorCommand::*cmd_calibrate* a)
     )
   )

  (:start-grasp
   (&optional (arm :arms))
   (send self :go-grasp arm :pos 0)
   )

  (:stop-grasp
   (&optional (arm :arms))
   (send self :go-grasp arm :pos 100)
   )

  (:go-grasp
   (&optional (arm :arms) &key ((:pos pos) 0))
   (dolist (a (if (eq arm :arms) (list "left" "right") (list (if (eq arm :rarm) "right" "left"))))
     (send self :command-grasp baxter_core_msgs::EndEffectorCommand::*cmd_go* a :pos pos)
     )
   )

  (:command-grasp
   (cmd arm &key ((:pos pos) nil))
   (let ((ee-cmd (instance baxter_core_msgs::EndEffectorCommand :init)))
     (send ee-cmd :id 65538)
     (send ee-cmd :command cmd)
     (send ee-cmd :sender "/baxter_interface")
     (send ee-cmd :sequence gripper-sequence-id)
     (if pos
         (send ee-cmd :args (format nil "{\"position\": ~A}" pos)))
     (ros::publish (format nil "/robot/end_effector/~A_gripper/command" arm) ee-cmd)
     (setq gripper-sequence-id (1+ gripper-sequence-id))
     )
   )
  )

(defun baxter-init ()
  (if (not (boundp '*ri*))
      (setq *ri* (instance baxter-interface :init)))
  (if (not (boundp '*baxter*))
      (setq *baxter* (instance baxter-robot :init)))
  (send *ri* :calib-grasp :arms)
  )