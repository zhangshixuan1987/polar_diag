  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

; Purpose: A tempolate to make a eof plot for AAO patterns 
;          Data is vertically interpolated to pressure levels
;          1st panel: EOFs for the first three modes
;          2nd panel: time series plot
; Author : Shixuan Zhang
; Date   : Dec 06, 2020

begin

  compare                                    = getenv("COMPARE")
  tpath                                      = getenv("TPATH")
  cpath                                      = getenv("CPATH")
  case1name                                  = getenv("TEST_NAME")
  case2name                                  = getenv("CTRL_NAME")
  casedir                                    = getenv("CASEDIR")
  opath                                      = getenv("DIAG_DATA_ROOT")

;define regions for eof analysis
  latS                                       = -90.  ;negative for southern hemisphere
  latN                                       = -20.  ;negative for southern hemisphere

;define # of desired EOFs
  neof                                       = 1     ; Leading EOF only

;define constants for unit conversion
  pi                                         = 3.14159265
  rearth                                     = 6.37122e6
  grav                                       = 9.80665

;variable name in the climo file
  modvars                                    = (/"Z3"/)
  obsvars                                    = (/"z"/) 
  seasons                                    = (/"ANN","DJF","JJA"/)
  preslev                                    = (/300,50/)

;read in two files

  do ll = 0,dimsizes(preslev) - 1

        f                                      = systemfunc("ls "+tpath+"/*_monthly_means.nc")
        f1                                     = addfile(f,"r")
        ps1                                    = f1->PS
        ha1                                    = doubletofloat(f1->hyam)
        hb1                                    = doubletofloat(f1->hybm)
        p0                                     = doubletofloat(f1->P0)
        p1                                     = pres_hybrid_ccm(ps1,p0,ha1,hb1)
        p1                                     = p1/100.
        gw1                                    = doubletofloat(f1->gw)

        if(compare.eq."Model_vs_OBS") then
          f                                    = systemfunc("ls "+cpath+"/*_prelev_monthly_analysis_*.nc")
          f2                                   = addfile(f,"r")
          gw2                                  = doubletofloat(f2->gw)
        else
          f                                    = systemfunc("ls "+cpath+"/*_monthly_means.nc")
          f2                                   = addfile(f,"r")
          ps2                                  = f2->PS
          ha2                                  = doubletofloat(f2->hyai)
          hb2                                  = doubletofloat(f2->hybi)
          p2                                   = pres_hybrid_ccm(ps2,p0,ha2,hb2)
          gw2                                  = doubletofloat(f2->gw)
        end if

        do jj = 0, dimsizes(modvars)-1

           mvarnam                             = modvars(jj)
           var1                                = f1->$mvarnam$
           tmp1                                = int2p_n_Wrap(p1,var1,preslev(ll),2,1)
           vp1                                 = tmp1(:,0,:,:)
           delete([/tmp1/])
 
           if(compare.eq."Model_vs_OBS") then
              ovarnam                          = obsvars(jj)
              var2                             = f2->$ovarnam$
              vp2                              = var2(:,{preslev(ll)},:,:)
              if(ovarnam.eq."z")then
                 vp2                           = vp2/grav ; covert geopoential to geoptential height
              end if 
           else
              var2                             = f2->$mvarnam$
              tmp2                             = int2p_n_Wrap(p1,var2,preslev(ll),2,1)
              vp2                              = tmp2(:,0,:,:)
              delete([/tmp2/])
           end if  
 
           if  ( preslev(ll) .gt. 1000. ) then
               vp1(:,0,:,:)                    = (/var1(:,ddd1(1)-1,:,:)/)
               vp2(:,0,:,:)                    = (/var2(:,ddd2(1)-1,:,:)/)
           end if
           delete([/var1,var2/])

           vp1@_FillValue                      = -9999.
           vp2@_FillValue                      = -9999.
           ddd1                                = dimsizes(vp1)
           ddd2                                = dimsizes(vp2)


           ;printVarSummary(vp1)
           ;printVarSummary(vp2)
         
           ;;check the two comparing files and see if they are in the same grid, otherwise, return the error message;;;;
           if ((ddd1(1).ne.ddd2(1)).or.(ddd1(2).ne.ddd2(2)))then
            print("Error: this scripts requires the two files must in the same grid to run!!!")
            return
           end if

       ; ==============================================================
       ; User defined parameters that specify region of globe
       ; ==============================================================
         x1     = vp1(:,{latS:latN},:)
         y1     = vp2(:,{latS:latN},:)
         delete([/vp1,vp2/])

       ; ==============================================================
       ; compute climatology and Anomalies
       ; ==============================================================
         xClm1  = clmMonTLL(x1)                      ; (12,lat,lon)
         yClm1  = clmMonTLL(y1)

         xAnom1 = calcMonAnomTLL(x1, xClm1)
         yAnom1 = calcMonAnomTLL(y1, yClm1)

         ;printVarSummary(xAnom1)
         ;printMinMax(xAnom1, True)

         ;printVarSummary(xAnom1)         
         ;printMinMax(xAnom1, True)

       ; =================================================================
       ; create weights:  sqrt(cos(lat))   [or sqrt(gw) ]
       ; =================================================================
         rad    = get_d2r("float")
         xclat  = xAnom1&lat            
         xclat  = sqrt( cos(rad*xclat) )                 ; gw for gaussian grid
         yclat  = yAnom1&lat 
         yclat  = sqrt( cos(rad*yclat) )                 ; gw for gaussian grid
   
       ; =================================================================
       ; weight all data 
       ; =================================================================
         xw1     = xAnom1*conform(xAnom1, xclat, 1)
         yw1     = yAnom1*conform(yAnom1, yclat, 1)
         copy_VarMeta(x1, xw1)
         copy_VarMeta(y1, yw1) 
         xw1@long_name = "Wgt: "+x1@long_name
         yw1@long_name = "Wgt: "+y1@long_name

     do kk = 0,dimsizes(seasons) - 1

       ; =================================================================
       ; Select different season for the eof
       ; =================================================================
         utc_date1 = cd_calendar(xw1&time,0)
         utc_date2 = cd_calendar(yw1&time,0)
         monthx1   = tointeger(utc_date1(:,1))
         monthx2   = tointeger(utc_date2(:,1))

         if(seasons(kk).eq."ANN")then

           indx1 = ind ((monthx1.ge.1).and.(monthx1.le.12))
           indx2 = ind ((monthx2.ge.1).and.(monthx2.le.12))

         else if (seasons(kk).eq."DJF")then

           indx1 = ind ((monthx1.eq.12).or.(monthx1.eq.1).or.(monthx1.eq.2))
           indx2 = ind ((monthx2.eq.12).or.(monthx2.eq.1).or.(monthx2.eq.2))
  
         else if (seasons(kk).eq."JJA") then

           indx1 = ind ((monthx1.eq.6).or.(monthx1.eq.7).or.(monthx1.eq.8))
           indx2 = ind ((monthx2.eq.6).or.(monthx2.eq.7).or.(monthx2.eq.8))

         else

           print("User did not specify the season, use all of the monthly data")
           indx1 = ind ((monthx1.ge.1).and.(monthx1.le.12))
           indx2 = ind ((monthx2.ge.1).and.(monthx2.le.12))

         end if
         end if
         end if

         xw    = xw1(indx1,:,:)
         yw    = yw1(indx2,:,:)
         xAnom = xAnom1(indx1,:,:)
         yAnom = yAnom1(indx2,:,:)

         xClm  = dim_avg_n_Wrap(x1(indx1,:,:),0) 
         yClm  = dim_avg_n_Wrap(y1(indx2,:,:),0)

         delete([/indx1,indx2,utc_date1,utc_date2,monthx1,monthx2/])

       ; =================================================================
       ; Compute EOFs & Standardize time series
       ; =================================================================
         optEOF  = True
         optETS  = False

         eof1    = eofunc_n_Wrap(xw, neof, optEOF, 0)      
         eof2    = eofunc_n_Wrap(yw, neof, optEOF, 0)
    
         do n = 0,neof-1
          pcor = pattern_cor(eof1(n,:,:),eof2(n,:,:),1.0,0)
          if(pcor.lt.0)then
            eof1(n,:,:) = eof1(n,:,:) * -1.0
          end if
         end do 

         eof1_ts = eofunc_ts_n_Wrap (xw, eof1, optETS, 0)
         eof2_ts = eofunc_ts_n_Wrap (yw, eof2, optETS, 0)

         eof1_ts = dim_standardize_n( eof1_ts, 0, 1)      ; normalize
         eof2_ts = dim_standardize_n( eof2_ts, 0, 1)      ; normalize

         ;printVarSummary( eof1 )                         ; examine EOF variables
         ;printVarSummary( eof1_ts )

         ;printVarSummary( eof2 )                         ; examine EOF variables
         ;printVarSummary( eof2_ts )

        ;======================================================================
        ;Save the data for the regression analysis
        ;======================================================================
         setfileoption("nc", "Format",  "NetCDF4")
         out_file1  = opath +"/"+"Polar_vortex_PCS_"+case1name+"_monthly_mean_"+mvarnam+"_at_"+toint(preslev(ll))+"hPa_"+seasons(kk)+".nc"
         out_file2  = opath +"/"+"Polar_vortex_PCS_"+case2name+"_monthly_mean_"+mvarnam+"_at_"+toint(preslev(ll))+"hPa_"+seasons(kk)+".nc"

         system("rm " + out_file1)
         system("rm " + out_file2)

         fout1 = addfile(out_file1,"c")
         fout2 = addfile(out_file2,"c")

         time1 = eof1_ts&time
         time2 = eof2_ts&time
         time1!0 = "time"
         time2!0 = "time"
         time1&time = time1
         time2&time = time2

         fout1->time         = time1
         fout2->time         = time2
         eof1@description    = "EOF pattern"
         eof2@description    = "EOF pattern"
         eof1_ts@description = "EOF PCs (standardized)"
         eof2_ts@description = "EOF PCs (standardized)"

         fout1->eof      = eof1
         fout2->eof      = eof2
         fout1->eof_ts   = eof1_ts
         fout2->eof_ts   = eof2_ts

         delete([/time1,time2,fout1,fout2,out_file1,out_file2/])

       ; =================================================================
       ; Regress
       ; =================================================================

         eof1_regres = eof1                               ; create an array w meta data
         eof2_regres = eof2                               ; create an array w meta data
         do ne=0,neof-1

            eof1_regres(ne,:,:) = (/ regCoef_n(eof1_ts(ne,:), xAnom, 0, 0) /)
            eof2_regres(ne,:,:) = (/ regCoef_n(eof2_ts(ne,:), yAnom, 0, 0) /)

         end do

       ; =================================================================
       ; Extract the YYYYMM from the time coordinate 
       ; associated with eof_ts [same as x&time] 
       ; =================================================================


         utc_date1 = cd_calendar(eof1_ts&time,-1)
         utc_date2 = cd_calendar(eof2_ts&time,-1)

         yyyy1     = yyyymm_to_yyyyfrac(utc_date1, 0.0) ;utc_date1(:,0)
         yyyy2     = yyyymm_to_yyyyfrac(utc_date2, 0.0) ;utc_date2(:,0)

         delete([/utc_date1,utc_date2/])
 
         wtype                        = "eps"
        ;wtype@wkWidth                = 2500
        ;wtype@wkHeight               = 2500
         fe                        = modvars(jj)+"_"+seasons(kk)+"_monthly_mean_" + preslev(ll)+"hPa"
         wks                          = gsn_open_wks(wtype,casedir+"/Polar_Votex/"   + fe)

         plot      = new((/6/),graphic)
         tsmap1    = new((/6/),graphic)
         tsmap2    = new((/6/),graphic)
      
       ;============================================================
       ; PLOTS
       ;============================================================
         res                      = True         
         res@gsnDraw              = False        ; don't draw yet
         res@gsnFrame             = False        ; don't advance frame yet
         res@gsnPolar             = "SH"
 
         res@mpFillOn             = False        ; turn off map fill
         res@mpMaxLatF            = latN
        ;res@mpCenterLonF         = 180

         FontHeightF = 0.018
         res@tiMainFontHeightF        = FontHeightF*1.5
         res@tmYLLabelFontHeightF     = FontHeightF
         res@tmXBLabelFontHeightF     = FontHeightF
         res@lbLabelFontHeightF       = FontHeightF
         res@gsnStringFontHeightF     = FontHeightF*1.2

         res@cnFillOn                 = True         ; turn on color fill
         res@cnLinesOn                = False        ; True is default
         res@cnLineLabelsOn           = False        ; True is default

         res@lbLabelBarOn             = True
         res@lbOrientation            = "Vertical"
         res@lbTitleString            = "Z"+preslev(ll)+" (gpm)" ;Geopential height (gpm)";
         res@lbTitlePosition          = "Right"                           ; title location
         res@lbTitleDirection         = "Across"                          ; letter angle
         res@lbTitleAngleF            = 90.                               ; title angle
         res@lbTitleFontHeightF       = FontHeightF                    ; font height
        ;res@pmLabelBarParallelPosF   = 0.61
         res@pmLabelBarOrthogonalPosF = 0.15

         res@tmXTOn                   = False
         res@tmYLLabelFontHeightF     = 0.025
         res@tmBorderThicknessF       = 1.0
         res@tmXBMajorThicknessF      = 1.0
         res@tmXBMinorThicknessF      = 1.0
         res@tmYLMajorThicknessF      = 1.0
         res@tmYLMinorThicknessF      = 1.0
         res@tmYRMajorThicknessF      = 1.0
         res@tmYRMinorThicknessF      = 1.0

        res@mpLabelFontHeightF           = FontHeightF*2.0
        res@gsnPolarLabelFontHeightF     = FontHeightF

       ;*******************************************
       ; first plot
       ;*******************************************

        res@cnFillPalette  = "amwg256"
        res@lbBoxLinesOn   = False
        ;set symmetric plot min/ma
        tmpdat  = array_append_record (xClm1, yClm1, 0)
        mnmxint = nice_mnmxintvl (min(tmpdat),max(tmpdat),41,False)
        res@cnLevelSelectionMode = "ManualLevels"
        res@cnMinLevelValF       = mnmxint(0)
        res@cnMaxLevelValF       = mnmxint(1)
        res@cnLevelSpacingF      = mnmxint(2)
        res@lbLabelStride        = 2
        
        ;if(preslev(ll).eq.300)then
        ;  res@lbLabelStride            = 10
        ;  res@cnMinLevelValF           = 8000.                ; set the minimum contour level
        ;  res@cnMaxLevelValF           = 9680.             ; set the maximum contour level
        ;  res@cnLevelSpacingF          =   20.                ; *special* match CPC
        ;else
        ;  res@lbLabelStride            = 4
        ;  res@cnMinLevelValF           = 19000.                ; set the minimum contour level
        ;  res@cnMaxLevelValF           = 20680.             ; set the maximum contour level
        ;  res@cnLevelSpacingF          =    40.                ; *special* match CPC
        ;end if
        delete(tmpdat)

        ;---Draw first plot in upper left corner
        res@gsnLeftString     = "Geopotential height"
        res@gsnRightString    = toint(preslev(ll))+ " hPa"
        res@gsnCenterString   = "" ;case1name
        res@tiMainString      = "Case: "+case1name
        plot(0)   = gsn_csm_contour_map_polar(wks,xClm,res)

        ;---Draw second plot in upper right corner
        res@gsnLeftString     = "Geopotential height"
        res@gsnRightString    = toint(preslev(ll))+ " hPa"
        res@gsnCenterString   = "" ;case2name
        res@tiMainString      = "Case: "+case2name
        plot(1) = gsn_csm_contour_map_polar(wks,yClm,res)

       ;*******************************************
       ; second plot
       ;*******************************************
        res@cnFillPalette            = "amwg_blueyellowred";"BlueWhiteOrangeRed"
        res@lbBoxLinesOn   = True
        res@lbLabelStride  = 1

        ;set symmetric plot min/ma
        ;tmpdat = (/eof1_regres,eof2_regres/)
        ;symMinMaxPlt(tmpdat, 16, False, res)           ; contributed.ncl
        res@cnLevelSelectionMode     = "ManualLevels"   ; manually set the contour levels with the following 3 resources

        if(preslev(ll).eq.300)then

         res@cnMinLevelValF           = -25.             ; set the minimum contour level
         res@cnMaxLevelValF           =  25.             ; set the maximum contour level
         res@cnLevelSpacingF          =   5.             ; *special* match CPC

        else

         res@cnMinLevelValF           = -50.             ; set the minimum contour level
         res@cnMaxLevelValF           =  50.             ; set the maximum contour level
         res@cnLevelSpacingF          =  10.             ; *special* match CPC

        end if 
       ;delete(tmpdat)

        res@mpLabelFontHeightF           = FontHeightF*2.0
        res@gsnPolarLabelFontHeightF     = FontHeightF

        ;---Draw first plot in upper left corner
        res@gsnLeftString     = "EOF 1"
        res@gsnRightString    = sprintf("%5.1f", eof1@pcvar(0)) +"%"
        res@gsnCenterString   = "" ;case1name
        res@tiMainString      = "Case: "+case1name
        plot(2)   = gsn_csm_contour_map_polar(wks,eof1_regres(0,:,:),res)

        ;---Draw second plot in upper right corner
        res@gsnLeftString     = "EOF 1"
        res@gsnRightString    = sprintf("%5.1f", eof2@pcvar(0)) +"%"
        res@gsnCenterString   = "" ;case2name
        res@tiMainString      = "Case: "+case2name
        plot(3) = gsn_csm_contour_map_polar(wks,eof2_regres(0,:,:),res)
      
       ;*******************************************
       ; second plot
       ;*******************************************
        ; EOF time series  [bar form]

          rts           = True
          rts@gsnDraw   = False       ; don't draw yet
          rts@gsnFrame  = False       ; don't advance frame yet
          rts@gsnScale  = True        ; force text scaling               

          rts@tiYAxisString = "Standardized"          ; y-axis label      

          rts@vpHeightF = 0.40        ; Changes the aspect ratio
          rts@vpWidthF  = 0.85
          rts@vpXF      = 0.10        ; change start locations
          rts@vpYF      = 0.75        ; the plot

          rts@gsnYRefLine           = 0.              ; reference line   
         ;rts@gsnXYBarChart         = False ;True            ; create bar chart 
          rts@gsnAboveYRefLineColor = "red"           ; above ref line fill red
          rts@gsnBelowYRefLineColor = "blue"          ; below ref line fill blue
         ;rts@xyLineColors         := (/"red","blue"/)         ; colors for the above/blow

          rts@tmXTOn                       = False
          rts@tmYLLabelFontHeightF         = 0.025
          rts@tmBorderThicknessF           = 1.0
          rts@tmXBMajorThicknessF          = 1.0
          rts@tmXBMinorThicknessF          = 1.0
          rts@tmYLMajorThicknessF          = 1.0
          rts@tmYLMinorThicknessF          = 1.0
          rts@tmYRMajorThicknessF          = 1.0
          rts@tmYRMinorThicknessF          = 1.0

          rts@trYMinF                      = -3.0
          rts@trYMaxF                      =  3.0

         ;create individual plots
         ;---Draw third plot in lower left corner
          rts@gsnLeftString     = "EOF 1"
          rts@gsnRightString    = sprintf("%5.1f", eof1_regres@pcvar(0)) +"%"
          rts@tiMainString      = "" ;"Case: "+case1name
          xyarr1                   = wgt_runave_Wrap(eof1_ts(0,:),(/1.,3,5,6,5,3,1/), 0)
          plot(4) = gsn_csm_xy (wks,yyyy1,xyarr1,rts)
           
          rts1 = rts
          rts1@gsnXYBarChart       = False
          rts1@gsnLeftString       = ""
          rts1@gsnRightString      = ""
          rts1@gsnCenterString     = ""
          rts1@xyLineThicknesses   = 3            
          rts1@xyLineColors       := "Black"
          xyarr1                   = wgt_runave_Wrap(eof1_ts(0,:),(/1.,3,5,6,5,3,1/), 0)   
          tsmap1(4)            = gsn_csm_xy(wks,yyyy1,xyarr1,rts1) 
          overlay(plot(4),tsmap1(4))
          delete([/xyarr1/])


          ;---Draw fourth plot in upper right corner
          rts@gsnLeftString        = "EOF 1"
          rts@gsnRightString       = sprintf("%5.1f", eof2_regres@pcvar(0)) +"%"
          rts@tiMainString         = "" ;"Case: "+case2name
          xyarr2                   = wgt_runave_Wrap(eof2_ts(0,:),(/1.,3,5,6,5,3,1/), 0)
          plot(5) = gsn_csm_xy (wks,yyyy2,xyarr2,rts)

          rts2 = rts
          rts2@gsnXYBarChart       = False
          rts2@gsnLeftString       = ""
          rts2@gsnRightString      = ""
          rts2@gsnCenterString     = ""
          rts2@xyLineThicknesses   = 3 
          rts2@xyLineColors       := "Black"
          xyarr2                   = wgt_runave_Wrap(eof2_ts(0,:),(/1.,3,5,6,5,3,1/), 0) 
          tsmap2(5)            = gsn_csm_xy(wks,yyyy2,xyarr2,rts2)
          overlay(plot(5),tsmap2(5))
          delete([/xyarr2/])

       ; panel plot only resources
          pres1                          = True                ; mods desired
          pres1@gsnFrame                 = False               ; save panel until both ready
          pres1@gsnPanelBottom           = 0.65    ; space for label bar
          pres1@gsnPanelTop              = 0.95     ; only panel on lower half of page
          pres1@gsnPanelXF               = (/0.08,0.58/)
          gsn_panel(wks,plot(0:1),(/1,2/),pres1)          ; create first panel
 
          pres2                          = True                ; mods desired
          pres2@gsnFrame                 = False               ; save panel until both ready
          pres2@gsnPanelBottom           = 0.35    ; space for label bar
          pres2@gsnPanelTop              = 0.65     ; only panel on lower half of page
          pres2@gsnPanelXF               = (/0.08,0.58/)
          gsn_panel(wks,plot(2:3),(/1,2/),pres2)          ; create first panel
         
          pres3                           = True                ; mods desired
          pres3@gsnFrame                  = False               ; save panel until both ready
          pres3@gsnPanelBottom            = 0.05                ; draw from center to right edge
          pres3@gsnPanelTop               = 0.30		; draw from center to right edge 
          gsn_panel(wks,plot(4:5),(/1,2/),pres3)       ; create first panel
       
          frame(wks)                                   ; draw both on same page

         ; if (wtype .eq. "png") then
         ;    tmpa = systemfunc("convert "+fe+".png -trim del.png")
         ;    tmpb = systemfunc("mv del.png "+fe+".png")
         ; end if

        ;delete([/xyarr1,xyarr2,tsmap1,tsmap2/])
        delete([/eof1_regres,eof2_regres,yyyy1,yyyy2/])
        delete([/xClm,yClm/])
        delete([/xw,yw,xAnom,yAnom,eof1,eof2,eof1_ts,eof2_ts/])

        end do                                              ; end of looping over seasons

        delete([/xAnom1,yAnom1,xClm1,yClm1,xw1,yw1,x1,y1,xclat,yclat/])
        delete([/f1,ps1,ha1,hb1,p0,p1,gw1/])

       end do ; end of looping over variables 

       if(compare.eq."Model_vs_OBS") then
          delete([/f2,gw2/])
       else
          delete([/f2,ps2,ha2,hb2,p2/])
       end if          

  end do                                                    ; end of looping over pressure levels


end

