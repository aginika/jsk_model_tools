;;
;; assimp mesh reader for euslisp
;;
(require :eus-assimp "package://eus_assimp/euslisp/eus_assimp.so")

(defconstant *aiProcess_CalcTangentSpace*         #x1)
(defconstant *aiProcess_JoinIdenticalVertices*    #x2)
(defconstant *aiProcess_MakeLeftHanded*           #x4)
(defconstant *aiProcess_Triangulate*              #x8)
(defconstant *aiProcess_RemoveComponent*          #x10)
(defconstant *aiProcess_GenNormals*               #x20)
(defconstant *aiProcess_GenSmoothNormals*         #x40)
(defconstant *aiProcess_SplitLargeMeshes*         #x80)
(defconstant *aiProcess_PreTransformVertices*     #x100)
(defconstant *aiProcess_LimitBoneWeights*         #x200)
(defconstant *aiProcess_ValidateDataStructure*    #x400)
(defconstant *aiProcess_ImproveCacheLocality*     #x800)
(defconstant *aiProcess_RemoveRedundantMaterials* #x1000)
(defconstant *aiProcess_FixInfacingNormals*       #x2000)
(defconstant *aiProcess_SortByPType*              #x8000)
(defconstant *aiProcess_FindDegenerates*          #x10000)
(defconstant *aiProcess_FindInvalidData*          #x20000)
(defconstant *aiProcess_GenUVCoords*              #x40000)
(defconstant *aiProcess_TransformUVCoords*        #x80000)
(defconstant *aiProcess_FindInstances*            #x100000)
(defconstant *aiProcess_OptimizeMeshes*           #x200000)
(defconstant *aiProcess_OptimizeGraph*            #x400000)
(defconstant *aiProcess_FlipUVs*                  #x800000)
(defconstant *aiProcess_FlipWindingOrder*         #x1000000)
(defconstant *aiProcess_SplitByBoneCount*         #x2000000)
(defconstant *aiProcess_Debone*                   #x4000000)

(defun load-mesh-file (fname &key ((:scale scl) 1.0) (gen-normal) (smooth-normal)
                             (split-large-mesh) (optimize-mesh) (identical-vertices) (fix-normal)
                             (process-fast) (process-quality) (process-max-quality)
                             (direction :z_up) (dump-filename) &allow-other-keys)
  ;; detect direction
  (case direction
    ((:x_up :x-up) (setq direction 0))
    ((:y_up :y-up) (setq direction 1))
    ((:z_up :z-up) (setq direction 2))
    ((:-x_up :-x-up) (setq direction 3))
    ((:-y_up :-y-up) (setq direction 4))
    ((numberp direction) );; do-nothing
    (t
     (warn ";; unknown direction ~A~%" direction)))
  ;; parse option
  (let ((post-process-options (list *aiProcess_Triangulate* *aiProcess_SortByPType*)))
    (if gen-normal (push *aiProcess_GenNormals* post-process-options))
    (if smooth-normal (push *aiProcess_GenSmoothNormals* post-process-options))
    (if split-large-mesh (push *aiProcess_SplitLargeMeshes* post-process-options))
    (if optimize-mesh (push *aiProcess_OptimizeMeshes* post-process-options))
    (if identical-vertices (push *aiProcess_JoinIdenticalVertices* post-process-options))
    (if fix-normal (push *aiProcess_FixInfacingNormals* post-process-options))
    (if process-fast (setq post-process-options
                           (append post-process-options
                                   (list *aiProcess_CalcTangentSpace*
                                         *aiProcess_GenNormals*
                                         *aiProcess_JoinIdenticalVertices*
                                         *aiProcess_GenUVCoords*))))
    (if process-quality (setq post-process-options
                              (append post-process-options
                                      (list *aiProcess_CalcTangentSpace*
                                            *aiProcess_GenNormals*
                                            *aiProcess_JoinIdenticalVertices*
                                            *aiProcess_ImproveCacheLocality*
                                            *aiProcess_LimitBoneWeights*
                                            *aiProcess_RemoveRedundantMaterials*
                                            *aiProcess_SplitLargeMeshes*
                                            *aiProcess_FindDegenerates*
                                            *aiProcess_FindInvalidData*
                                            *aiProcess_GenUVCoords*))))
    (if process-max-quality (setq post-process-options
                              (append post-process-options
                                      (list *aiProcess_CalcTangentSpace*
                                            *aiProcess_GenNormals*
                                            *aiProcess_JoinIdenticalVertices*
                                            *aiProcess_ImproveCacheLocality*
                                            *aiProcess_LimitBoneWeights*
                                            *aiProcess_RemoveRedundantMaterials*
                                            *aiProcess_SplitLargeMeshes*
                                            *aiProcess_FindDegenerates*
                                            *aiProcess_FindInvalidData*
                                            *aiProcess_GenUVCoords*
                                            *aiProcess_FindInstances*
                                            *aiProcess_ValidateDataStructure*
                                            *aiProcess_OptimizeMeshes*
                                            *aiProcess_Debone*))))
    (setq post-process-options
          (apply #'+
                 (remove-duplicates post-process-options :test #'=)))
    (let ((ret
           (c-assimp-get-glvertices fname scl
                                    post-process-options
                                    direction dump-filename))
          glv)
      (when ret
        (let ((fp (pathname fname)))
          (setq glv (instance gl::glvertices :init ret))
          (send glv :filename fname)
          (send glv :load-texture-image
                (pathname-directory (truename fp))))
        glv)
      )))

(defun save-mesh-file (fname glvtcs
                               &key ((:scale scl) 1.0) (gen-normal) (smooth-normal)
                               (split-large-mesh) (optimize-mesh) (identical-vertices)
                               &allow-other-keys)
  (when (substringp ".wrl" fname)
    (dump-glvertices-to-wrl fname glvtcs :scale scl)
    (return-from save-mesh-file))
  (let ((mlst (glvtcs . gl::mesh-list))
        name-lst type-lst
        material-lst
        vertices-lst
        normals-lst
        texcoords-lst
        indices-lst)
    (dolist (m mlst)
      (push (case (cadr (assoc :type m))
              (:triangles 3)
              (:quads 4)
              (t 0)) type-lst)
      (let ((mat (cadr (assoc :material m))))
        (push
         (mapcar #'(lambda (x)
                     (cadr (assoc x mat)))
                 (list :ambient :diffuse :specular :emission :shininess :transparency :filename))
         material-lst))
      (push (cadr (assoc :vertices m)) vertices-lst)
      (push (cadr (assoc :normals m)) normals-lst)
      (push (cadr (assoc :texcoords m)) texcoords-lst)
      (push (cadr (assoc :indices m)) indices-lst)
      (push (cadr (assoc :name m)) name-lst)
      )
    ;;(pprint (nreverse material-lst))
    ;;(pprint (nreverse texcoords-lst))
    ;;(nreverse vertices-lst) (nreverse normals-lst) (nreverse indices-lst)))
    (c-assimp-dump-glvertices fname
                              (nreverse type-lst) (nreverse material-lst)
                              (nreverse vertices-lst) (nreverse normals-lst)
                              (nreverse texcoords-lst) (nreverse indices-lst)
                              scl gen-normal smooth-normal
                              split-large-mesh optimize-mesh identical-vertices)
    ))
(setf (symbol-function 'store-glvertices)
      (symbol-function 'save-mesh-file))
;;
(defun append-glvertices (glv-lst)
  (let (ret)
    (dolist (glv glv-lst)
      (let ((mlst (glv . gl::mesh-list))
            (cds (send glv :worldcoords)))
        ;; not concerning coordinates
        (setq ret (append ret mlst))
        ))
    (instance gl::glvertices :init ret)))

(defun convex-decomposition-glvertices (glvtcs
                                        &key (add-color nil) (color-num 8)
                                        (skinwidth 0.0)
                                        (decomposition-depth 4) ;; if larger, reduce faces
                                        (max-hull-vertices 48) ;; if larger, increase faces
                                        (concavity-threshold 10) ;; if larger, reduce faces
                                        (merge-threshold 20.0) ;; if larger, reduce faces
                                        (volume-split-threshold 4.0) ;; if larger, reduce faces
                                        )
  (let ((mlst (glvtcs . gl::mesh-list))
        ;;name-lst ;; type-lst
        ;;material-lst ;;normals-lst
        vertices-lst
        indices-lst
        ret glv)
    (dolist (m mlst)
      (when (eq :triangles (cadr (assoc :type m)))
        (push (cadr (assoc :vertices m)) vertices-lst)
        (push (cadr (assoc :indices m)) indices-lst)))
    (setq ret (c-convex-decomposition-glvertices
               (nreverse vertices-lst) (nreverse indices-lst)
               skinwidth decomposition-depth max-hull-vertices
               concavity-threshold merge-threshold volume-split-threshold))
    (when ret
      (setq glv (instance gl::glvertices :init ret))
      (when add-color
        (let ((mlst (glv . gl::mesh-list))
              (cntr 0) (mesh-num 0))
          (dolist (m mlst)
            (let ((mat (cadr (assoc :material m))))
              (if mat
                  (setf (cdr mat)
                        (list :material
                              (list (llist :ambient (scale (* 0.8 (/ 1 255.0)) (coerce (his2rgb (* (/ (mod cntr color-num)
                                                                                              (float color-num)) 360) 1 1) float-vector)))
                                    (list :diffuse (scale (* 0.8 (/ 1 255.0)) (coerce (his2rgb (* (/ (mod cntr color-num)
                                                                                             (float color-num)) 360) 1 1) float-vector))))))
                (nconc m
                       (list (list :material
                                   (list (list :ambient (scale (* 0.8 (/ 1 255.0)) (coerce (his2rgb (* (/ (mod cntr color-num)
                                                                                                  (float color-num)) 360) 1 1) float-vector)))
                                         (list :diffuse (scale (* 0.8 (/ 1 255.0)) (coerce (his2rgb (* (/ (mod cntr color-num)
                                                                                                  (float color-num)) 360) 1 1) float-vector)))))))))
            (incf mesh-num (/ (length (cadr (assoc :indices m))) 3))
            (incf cntr))
          (format t ";; result: ~A meshes, total ~A faces~%" cntr mesh-num)
          ))
      glv)
    ))

(when (and (fboundp 'c-assimp-load-image)
           (not (fboundp 'read-image-file-org)))
  (defun assimp-read-image-file (fname)
    (let* ((ret (c-assimp-load-image fname))
           (w (cadr (assoc :width ret)))
           (h (cadr (assoc :height ret)))
           (byte/pixel (cadr (assoc :type ret)))
           (buf (cadr (assoc :vertices ret))))
      (when ret
        (case byte/pixel
          (1
           (instance grayscale-image :init w h buf))
          (3
           (instance color-image24 :init w h buf))
          (4
           (instance color-image32 :init w h buf))
          (t
           (warn ";; not implemented byte/pixel ~d~%" byte/pixel)
           )))))
  (setf (symbol-function 'read-image-file-org)
        (symbol-function 'read-image-file))
  ;; override read-image-file
  (defun read-image-file (fname)
    (let ((r (read-image-file-org fname)))
      (unless r
        (setq r (assimp-read-image-file fname)))
      r))
  )

(defun make-glvertices-from-faceset (fs &key (material))
  (let (mat)
    (cond
     (material (setq mat material))
     ((get fs :face-color)
      (let ((col (get fs :face-color)))
        (unless (vectorp col)
          (setq col (gl::find-color col)))
        (setq mat
              (list (list :ambient (float-vector (elt col 0) (elt col 1) (elt col 2)))
                    (list :diffuse (float-vector (elt col 0) (elt col 1) (elt col 2)))))))
     (t
      ;; default material
      (setq mat
            (list (list :ambient (float-vector 0.65 0.65 0.65))
                  (list :diffuse (float-vector 0.65 0.65 0.65))))))
    (make-glvertices-from-faces (send fs :faces) :material mat)))

(defun make-glvertices-from-faces (flst &key (material))
  (setq flst (flatten (mapcar #'(lambda (f) (geometry::face-to-triangle-aux f)) flst)))
  (let ((mat (make-matrix (* 3 (length flst)) 3))
        (nom (make-matrix (* 3 (length flst)) 3))
        (idx (instantiate integer-vector (* 3 (length flst))))
        (cntr 0))
    (dolist (f flst)
      (let ((nm (normalize-vector (send f :normal)))
            (vsl (send f :vertices)))
        (c-matrix-row mat cntr (car vsl) t)
        (c-matrix-row nom cntr nm t)
        (incf cntr)

        (c-matrix-row mat cntr (cadr vsl) t)
        (c-matrix-row nom cntr nm t)
        (incf cntr)

        (c-matrix-row mat cntr (caddr vsl) t)
        (c-matrix-row nom cntr nm t)
        (incf cntr)
        ))
    (dotimes (i (length idx)) (setf (elt idx i) i))

    (let ((msh
           (list (list :type :triangles)
                 (list :vertices mat)
                 (list :normals nom)
                 (list :indices idx))))
      (when material
        (push (list :material material) msh))
      (instance gl::glvertices :init (list msh)))
    ))

(defun dump-to-meshfile (fname obj &rest args &key (material) &allow-other-keys)
  (let (faces)
    (cond
     ((find-method obj :bodies)
      (let (glv-lst)
        (dolist (bd (send obj :bodies))
          (let (mat)
            (if material (setq mat material))
            ;; TODO: get color and set matterial
            (push (funcall #'make-glvertices-from-faces faces :material mat) glv-lst)))
        (apply #'store-glvertices fname (append-glvertices glv-lst) args)
        ))
     ((find-method obj :faces)
      (setq faces (send obj :faces))
      (apply #'store-glvertices
             fname
             (funcall #'make-glvertices-from-faces faces :material material) args))
     (t
      (warn ";; face not found~%")
      ))
    fname))

(defun make-cube-from-bounding-box (bbox &rest args)
  (let ((cds (make-coords :pos (send bbox :center)))
        (dsize (send bbox :diagonal)) ret)
    (setq ret (apply #'make-cube (elt dsize 0) (elt dsize 1) (elt dsize 2) args))
    (send ret :translate-vertices (send cds :pos))
    ret))

;; urdf_to_collada -> collada2eus ..
(defun update-to-original-meshfile (robot &key (scale 1000.0) (direction :z_up))
  (dolist (bd (send robot :bodies))
    (let ((str (send bd :name)))
      (when (and (stringp str)
                 (substringp ".dae" str))
        (let ((fn (ros::resolve-ros-path str))
              (old-glv (bd . glvertices))
              glv)
          (setq glv (load-mesh-file fn :scale scale :direction direction))
          (send glv :transform (send old-glv :worldcoords))
          (let ((p (send old-glv :parent)))
            (send p :dissoc old-glv)
            (send p :assoc glv))
          (setq (bd . glvertices) glv))
        )))
  robot)

(defun _dump-wrl-shape (strm mesh &key ((:scale scl) 1.0))
  (let* ((tp   (cadr (assoc :type      mesh))) ;; type should be :triangle
         (indx (cadr (assoc :indices   mesh))) ;; should have index
         (vmat (cadr (assoc :vertices  mesh)))
         (matl (cadr (assoc :material  mesh)))
         ;;(tcds (cadr (assoc :texcoords mesh))) ;; not used ...
         (len (/ (length (array-entity vmat)) 3)))
    (format strm "    Shape {~%")
    (let ((col   (cadr (assoc :color matl)))
          (amb   (cadr (assoc :ambient matl)))
          (diff  (cadr (assoc :diffuse matl)))
          (spec  (cadr (assoc :specular matl)))
          (emi   (cadr (assoc :emission matl)))
          (shin  (cadr (assoc :shininess matl)))
          (trans (cadr (assoc :transparency matl))))
      (format strm "      appearance Appearance {
        material Material {~%")
      (if diff
          (format strm "          diffuseColor     ~f ~f ~f~%" (elt diff 0) (elt diff 1) (elt diff 2)))
      ;;(if amb ;; not use ambient
      ;;(format strm "          diffuseColor     ~f ~f ~f~%" (elt amb 0) (elt amb 1) (elt amb 2)))
      (if spec
          (format strm "          specularColor    ~f ~f ~f~%" (elt spec 0) (elt spec 1) (elt spec 2)))
      (if emi
          (format strm "          emissiveColor    ~f ~f ~f~%" (elt emi 0) (elt emi 1) (elt emi 2)))
      (if shin
          (format strm "          shininess        ~f~%" shin))
      (if trans
          (format strm "          transparency     ~f~%" trans))
      (format strm "          ambientIntensity 0~%") ;; ??
      (format strm "        }~%")
      (format strm "      }~%" )
      )
    (format strm "      geometry IndexedFaceSet {
        ccw    TRUE
        convex TRUE
        solid  FALSE
        creaseAngle 0
        coord  Coordinate {
          point [~%")
    (let ((p (float-vector 0 0 0)))
      (dotimes (i len)
        (user::c-matrix-row vmat i p)
        (format strm "~8,8f ~8,8f ~8,8f,~%" (* scl (elt p 0)) (* scl (elt p 1)) (* scl (elt p 2)))
        ))
    (format strm "                ]
        }~%")
    ;;;; normal
    ;;(format strm "        normal Normal { vector [~%")
    ;; nx ny nz,
    ;;(format strm "        ] } #normal~%")
    ;;;; texcoords
    ;;(format strm "        texCoord TextureCoordinate { point [~%")
    ;; t s,
    ;;(format strm "        ] } #texCoord~%")
    (format strm "        coordIndex [~%")
    (dotimes (i (/ (length indx) 3))
      (format strm "~D, ~D, ~D, -1,~%"
              (elt indx    (* i 3))
              (elt indx (+ (* i 3) 1))
              (elt indx (+ (* i 3) 2))))
    (format strm "        ]
      } #IndexedFaceSet
    } #Shape~%")
    ))

(defun dump-glvertices-to-wrl (fname glv &key ((:scale scl) 1.0))
  (let ((mesh-list (glv . gl::mesh-list)))
    (with-open-file
     (strm fname :direction :output)
     (format strm "Transform {~%")
     (format strm "  children [~%")
     (dolist (mesh mesh-list)
       (_dump-wrl-shape strm mesh :scale scl))
     (format strm "  ] #children~%")
     (format strm "} #Transform~%")
     )))

(in-package "GL")
(defmethod glvertices
  (:load-texture-image (&optional dir)
   (dolist (minfo mesh-list)
     (let ((matinfo (cadr (assoc :material minfo))))
       (let ((fname (cadr (assoc :filename matinfo)))
             (img   (cadr (assoc :teximage matinfo))))
         (when (and fname (null img))
           ;;(when (substringp ".tif" fname)
           ;;  (setq fname (format nil "~A.png" (subseq fname 0 (- (length fname) 4)))))
           ;; relative path -> absolute path
           (let ((pf (pathname fname)))
             (unless (or (null dir) (eq (car (pathname-directory pf)) :root)) ;; absolute path
               (setq (pf . directory) (append dir (pf . directory)))
               (setq fname (namestring pf))
               ))
           (setq img (image::read-image-file fname))
           ;; TODO: check color-image24 and packed to RGB24bit
           ;;(pprint (list fname img))
           (when img
             (nconc matinfo (list (list :teximage img))))
           ;;; load other method
           )
         )))
   )
  )
(in-package "USER")
