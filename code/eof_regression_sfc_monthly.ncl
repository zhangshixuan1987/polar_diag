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
  statistical_test                           = getenv("REGRESSION_TEST")
  statistical_siglev                         = 0.1

;define regions for eof analysis
  latS                                         = -90.  ;negative for southern hemisphere
  latN                                         = -20.  ;negative for southern hemisphere

;define # of desired EOFs
  neof                                         = 3     ; Leading EOF only
  eof                                       = (/"SAM", "PSA1", "PSA2"/)
  eofmodvar                                    = ("PSL")
  eofobsvar                                    = ("msl")

;define color for the plot of signiticant test 
  FillColor           = "Black";"Grey75" ;"Grey65";"Grey28";"Grey";"Black"
  FillPattern         = 0 ;17 ;6 ;17;11
  FillScaleF          = 5.0
  FillDotSizeF        = 0.00002    ; increase dot size of contours
  FillOpacityF        = 0.5 ;0.15

;define constants for unit conversion
  pi                                           = 3.14159265
  rearth                                       = 6.37122e6
  grav                                         = 9.80665

;variable name in the climo file
  modvars                                      = (/"PSL", "TS","TREFHT",  "U10", "PRECT", "CLDLOW","SWCF","LWCF"/)
  obsvars                                      = (/"msl","skt", "t2m"  , "si10", "mtpr" , "lcc",    "tsr", "ttr"/)
  seasons                                      = (/"ANN","DJF","JJA"/)
  preslev                                      = (/"Surface"/)

  maxlev                                       = 11
  minlev_eof1                                  = (/-200.,-0.5, -0.5, -0.5, -0.5, -0.02, -2., -1./)
  maxlev_eof1                                  = (/ 200., 0.5,  0.5,  0.5,  0.5,  0.02,  2.,  1./)

  minlev_eof2                                  = (/-100.,-0.5, -0.5, -0.5, -0.5, -0.02, -2., -1./)
  maxlev_eof2                                  = (/ 100., 0.5,  0.5,  0.5,  0.5,  0.02,  2.,  1./)

  minlev_eof3                                  = (/-100.,-0.5, -0.5, -0.5, -0.5, -0.02, -2., -1./)
  maxlev_eof3                                  = (/ 100., 0.5,  0.5,  0.5,  0.5,  0.02,  2.,  1./)

;read in two files

  do ll = 0,dimsizes(preslev) - 1

     do kk = 0,dimsizes(seasons) - 1

        f                                      = systemfunc("ls $TPATH/*_monthly_means.nc")
        f1                                     = addfile(f,"r")
        ps1                                    = f1->PS
        lat1                                   = f1->lat
        lon1                                   = f1->lon
        ha1                                    = doubletofloat(f1->hyam)
        hb1                                    = doubletofloat(f1->hybm)
        p0                                     = doubletofloat(f1->P0)
        p1                                     = pres_hybrid_ccm(ps1,p0,ha1,hb1)
        p1                                     = p1/100.
        gw1                                    = doubletofloat(f1->gw)

        if(compare.eq."Model_vs_OBS") then
          f                                    = systemfunc("ls $CPATH/*_siglev_monthly_analysis*.nc")
          f2                                   = addfile(f,"r")
          gw2                                  = doubletofloat(f2->gw)
          lat2                                 = f2->lat
          lon2                                 = f2->lon
        else
          f                                    = systemfunc("ls $CPATH/*_monthly_means.nc")
          f2                                   = addfile(f,"r")
          ps2                                  = f2->PS
          lat2                                 = f2->lat
          lon2                                 = f2->lon
          ha2                                  = doubletofloat(f2->hyai)
          hb2                                  = doubletofloat(f2->hybi)
          p2                                   = pres_hybrid_ccm(ps2,p0,ha2,hb2)
          p2                                   = p2/100.
          gw2                                  = doubletofloat(f2->gw)
        end if

        
        ;;;;;;derive eof time series;;;;;;;
         eofvp1                              = f1->$eofmodvar$

         if(compare.eq."Model_vs_OBS") then
            eofvp2                           = f2->$eofobsvar$
         else
            eofvp2                           = f2->$eofmodvar$
         end if

         eofvp1@_FillValue                   = -9999.
         eofvp2@_FillValue                   = -9999.
         edd1                                = dimsizes(eofvp1)
         edd2                                = dimsizes(eofvp2)

         ;;check the two comparing files and see if they are in the same grid, 
         ;;otherwise, return the error message;;;;
          if ((edd1(1).ne.edd2(1)).or.(edd1(2).ne.edd2(2)))then
           print("Error: this scripts requires the two files must in the same grid to run!!!")
           return
          end if

       ; ==============================================================
       ; User defined parameters that specify region of globe and
       ; ==============================================================
         eofx1  = eofvp1(:,{latS:latN},:)
         eofy1  = eofvp2(:,{latS:latN},:)

       ; ==============================================================
       ; compute climatology and Anomalies
       ; ==============================================================
         eofxClm1   = clmMonTLL(eofx1) 
         eofyClm1   = clmMonTLL(eofy1)

         eofxAnom1  = calcMonAnomTLL (eofx1, eofxClm1 )
         eofyAnom1  = calcMonAnomTLL (eofy1, eofyClm1 )

         ;printVarSummary(eofxAnom)
         ;printMinMax(eofxAnom, True)

       ; =================================================================
       ; create weights:  sqrt(cos(lat))   [or sqrt(gw) ]
       ; =================================================================
         rad    = get_d2r("float")
         eofxclat  = eofxAnom1&lat
         eofxclat  = sqrt( cos(rad*eofxclat) )                 ; gw for gaussian grid
         eofyclat  = eofyAnom1&lat
         eofyclat  = sqrt( cos(rad*eofyclat) )                 ; gw for gaussian grid

       ; =================================================================
       ; weight all data
       ; =================================================================
         eofxw1     = eofxAnom1*conform(eofxAnom1, eofxclat, 1)
         eofyw1     = eofyAnom1*conform(eofyAnom1, eofyclat, 1)
         copy_VarMeta(eofx1, eofxw1)
         copy_VarMeta(eofy1, eofyw1)
         eofxw1@long_name = "Wgt: "+eofx1@long_name
         eofyw1@long_name = "Wgt: "+eofy1@long_name

       ; =================================================================
       ; Select different season for the eof
       ; =================================================================
         utc_date1 = cd_calendar(eofxw1&time,0)
         utc_date2 = cd_calendar(eofyw1&time,0)
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

         eofxw    = eofxw1(indx1,:,:)
         eofyw    = eofyw1(indx2,:,:)

         delete([/indx1,indx2,eofxw1,eofyw1,utc_date1,utc_date2,monthx1,monthx2/])

       ; =================================================================
       ; Compute EOFs & Standardize time series
       ; =================================================================
         optEOF  = True
         optETS  = False

         eof1    = eofunc_n_Wrap(eofxw, neof, optEOF, 0)
         eof2    = eofunc_n_Wrap(eofyw, neof, optEOF, 0)

         do n = 0,neof-1
          pcor = pattern_cor(eof1(n,:,:),eof2(n,:,:),1.0,0)
          if(pcor.lt.0)then
            eof2(n,:,:) = eof2(n,:,:) * -1.0
          end if
         end do

         eof1_ts = eofunc_ts_n_Wrap (eofxw, eof1, optETS, 0)
         eof2_ts = eofunc_ts_n_Wrap (eofyw, eof2, optETS, 0)

         eof1_ts = dim_standardize_n( eof1_ts, 0, 1)      ; normalize
         eof2_ts = dim_standardize_n( eof2_ts, 0, 1)      ; normalize

         ;printVarSummary( eof1 )                         ; examine EOF variables
         ;printVarSummary( eof1_ts )

         ;printVarSummary( eof2 )                         ; examine EOF variables
         ;printVarSummary( eof2_ts )

         delete([/eofxAnom1,eofyAnom1,eofx1,eofy1,eofxclat,eofyclat/])

       ; =================================================================


        do jj = 0, dimsizes(modvars)-1

           mvarnam                             = modvars(jj)

           if(mvarnam.eq."PRECT") then
             vp1                               = f1->PRECC
             vp1                               = f1->PRECC + f1->PRECL
             vp1                               = vp1 * 1000.0 * 24.0 * 3600.0
             vp1@units                         = "mm day~S~-1~N~"
           else
             vp1                               = f1->$mvarnam$
           end if


           if(compare.eq."Model_vs_OBS") then

              ovarnam                          = obsvars(jj)
              if(mvarnam.eq."PRECT") then
                vp2                            = f2->$ovarnam$
                vp2                            = vp2 * 24.0 * 3600.0
                vp2@units                      = "mm day~S~-1~N~"
              else if (mvarnam.eq."SWCF") then
                vp2                            = f2->tsr
                vp2                            = f2->tsr - f2->tsrc
                vp2                            = vp2/86400.0 ; convert to W m^-2
                vp2@units                      = "W m~S~-2~N~"
              else if (mvarnam.eq."LWCF") then
                vp2                            = f2->ttr
                vp2                            = f2->ttr - f2->ttrc
                vp2                            = vp2/86400.0 ; convert to W m^-2
                vp2@units                      = "W m~S~-2~N~"
              else
                vp2                            = f2->$ovarnam$
              end if
              end if
              end if

           else

             if(mvarnam.eq."PRECT") then

               vp2                             = f2->PRECC
               vp2                             = f2->PRECC + f2->PRECL
               vp2                             = vp2 * 1000.0 * 24.0 * 3600.0
               vp2@units                       = "mm day~S~-1~N~"

             else

               vp2                             = f2->$mvarnam$
               vp2@units                       = "mm day~S~-1~N~"

             end if

           end if

           vp1@_FillValue                      = -9999.
           vp2@_FillValue                      = -9999.
           ddd1                                = dimsizes(vp1)
           ddd2                                = dimsizes(vp2)

           ;printVarSummary(vp1)
           ;printVarSummary(vp2)


           ;;check the two comparing files and see if they are in the same grid, 
           ;;otherwise, return the error message;;;;
           if ((ddd1(1).ne.ddd2(1)).or.(ddd1(2).ne.ddd2(2))) then 
            print("Error: this scripts requires the two files must in the same grid to run!!!")
            return
           end if

       ; ==============================================================
       ; User defined parameters that specify region of globe and
       ; ==============================================================
         regx1  = vp1(:,{latS:latN},:)
         regy1  = vp2(:,{latS:latN},:)

         latx1  = regx1&lat
         lonx1  = regx1&lon
         latx2  = regy1&lat
         lonx2  = regy1&lon

       ; ==============================================================
       ; compute climatology and Anomalies
       ; ==============================================================
         regxClm1   = clmMonTLL(regx1)                      ; (12,lat,lon)
         regyClm1   = clmMonTLL(regy1)

         regxAnom1  = calcMonAnomTLL (regx1, regxClm1 )
         regyAnom1  = calcMonAnomTLL (regy1, regyClm1 )

       ; =================================================================
       ; Select different season for the eof
       ; =================================================================
         utc_date1 = cd_calendar(regxAnom1&time,0)
         utc_date2 = cd_calendar(regyAnom1&time,0)
         monthx1   = tointeger(utc_date1(:,1))
         monthx2   = tointeger(utc_date2(:,2))

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

         regxAnom = regxAnom1(indx1,:,:)
         regyAnom = regyAnom1(indx2,:,:)

         delete([/indx1,indx2,regxAnom1,regyAnom1,utc_date1,utc_date2,monthx1,monthx2/])

       ; =================================================================
       ; Regress
       ; =================================================================

         eof1_regres = regxAnom                               ; create an array w meta data
         eof2_regres = regyAnom                               ; create an array w meta data
         eof1_regres@_FillValue = -9999.
         eof2_regres@_FillValue = -9999.
 
         ddeof1      = dimsizes(regxAnom)
         ddeof2      = dimsizes(regyAnom) 
         eof1_lat    = new((/ddeof1(0),ddeof1(1)*ddeof1(2)/),typeof(latx1))
         eof1_lon    = new((/ddeof1(0),ddeof1(1)*ddeof1(2)/),typeof(lonx1))
         eof2_lat    = new((/ddeof2(0),ddeof2(1)*ddeof2(2)/),typeof(latx2))
         eof2_lon    = new((/ddeof2(0),ddeof2(1)*ddeof2(2)/),typeof(lonx2))
         eof1_lat@_FillValue = -9999.
         eof1_lon@_FillValue = -9999.
         eof2_lat@_FillValue = -9999.
         eof2_lon@_FillValue = -9999.

         do ne=0,neof-1

            rc1   = regCoef_n(eof1_ts(ne,:), regxAnom, 0, 0)
            rc2   = regCoef_n(eof2_ts(ne,:), regyAnom, 0, 0)
            rc1@_FillValue = -9999.
            rc2@_FillValue = -9999.

            if (str_lower(statistical_test).eq. "true")then        
             l_plot_test = True 

             drc1  = dimsizes(rc1) 
             df1   = rc1@nptxy-2   ; degrees of freedom
             tval1 = rc1@tval      ; t-statistic
             xb1   = tval1
             xb1   = 0.50
             pb1   = betainc(df1/(df1+tval1^2),df1/2.0,xb1)
             lat11 = ndtooned(conform(rc1,latx1,0)) 
             lon11 = ndtooned(conform(rc1,lonx1,1))
             lat11 = where(pb1.le.statistical_siglev,lat11,rc1@_FillValue)
             lon11 = where(pb1.le.statistical_siglev,lon11,rc1@_FillValue)
             eof1_lat(ne,:) = lat11
             eof1_lon(ne,:) = lon11 
            ;prob1 = reshape(pb1,(/drc1(0),drc1(1)/))
            ;prob1 = where(prob1.le.statistical_siglev,rc1,rc1@_FillValue)
            ;eof1_prob(ne,:,:) = (/ prob1 /)
             delete([/drc1,df1,tval1,xb1,pb1,lat11,lon11/])

             drc2  = dimsizes(rc2)
             df2   = rc2@nptxy-2   ; degrees of freedom
             tval2 = rc2@tval      ; t-statistic
             xb2   = tval2
             xb2   = 0.50
             pb2   = betainc(df2/(df2+tval2^2),df2/2.0,xb2)
             lat12 = ndtooned(conform(rc2,latx2,0))
             lon12 = ndtooned(conform(rc2,lonx2,1))
             lat12 = where(pb2.le.statistical_siglev,lat12,rc2@_FillValue)
             lon12 = where(pb2.le.statistical_siglev,lon12,rc2@_FillValue)
             eof2_lat(ne,:) = lat12
             eof2_lon(ne,:) = lon12
            ;prob2 = reshape(pb2,(/drc2(0),drc2(1)/))
            ;prob2 = where(prob2.le.statistical_siglev,rc2,rc2@_FillValue)
            ;eof2_prob(ne,:,:) = (/ prob2 /)
             delete([/drc2,df2,tval2,xb2,pb2,lat12,lon12/])
            end if 

            eof1_regres(ne,:,:) = (/ doubletofloat(rc1) /)
            eof2_regres(ne,:,:) = (/ doubletofloat(rc2) /)
            delete([/rc1,rc2/])

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
 
       do n = 0, neof-1

         wtype                        = "eps"
        ;wtype@wkWidth                = 2500
        ;wtype@wkHeight               = 2500
         figdir                       = casedir+"/Regression_Contour_Maps/"
         fe                        = eof(n)+"_regression_on_"+modvars(jj)+"_"+seasons(kk)
         wks                          = gsn_open_wks(wtype, figdir + fe)
 
         plot      = new((/4/),graphic)
         tsmap1    = new((/4/),graphic)
         tsmap2    = new((/4/),graphic)
      
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
         res@cnFillPalette            = "BlueDarkRed18"  
         res@cnLinesOn                = False        ; True is default
         res@cnLineLabelsOn           = False        ; True is default

         res@lbLabelBarOn             = True
         res@lbOrientation            = "Vertical"
         res@lbTitleString            = mvarnam +" ("+regxAnom@units+")" ;Geopential height (gpm)";
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

        ;set symmetric plot min/ma
        ;tmpdat = (/eof1_regres,eof2_regres/)
        ;symMinMaxPlt(tmpdat, 16, False, res)      ; contributed.ncl
        ;delete(tmpdat)

        res@cnLevelSelectionMode = "ManualLevels"  ; manually set the contour levels with the following 3 resources
        if(n.eq.0)then
          mnmxint = nice_mnmxintvl( minlev_eof1(jj), maxlev_eof1(jj), maxlev, False)
        else if (n.eq.1)then 
          mnmxint = nice_mnmxintvl( minlev_eof2(jj), maxlev_eof2(jj), maxlev, False)
        else
          mnmxint = nice_mnmxintvl( minlev_eof3(jj), maxlev_eof3(jj), maxlev, False)
        end if 
        end if
  
        res@cnMinLevelValF           = mnmxint(0) ; set the minimum contour level
        res@cnMaxLevelValF           = mnmxint(1) ; set the maximum contour level     
        res@cnLevelSpacingF          = mnmxint(2) ; *special* match CPC

        delete([/mnmxint/])

       ;*******************************************
       ; first plot
       ;*******************************************
          res@mpLabelFontHeightF           = FontHeightF*2.0
          res@gsnPolarLabelFontHeightF     = FontHeightF

          ;---Draw first plot in upper left corner
          res@gsnLeftString     = "Regression ("+eof(n)+")";(EOF "+(n+1)+")"
          res@gsnRightString    = sprintf("%5.1f", eof1@pcvar(n)) +"%"
          res@gsnCenterString   = "" ;case1name
          res@tiMainString      = "Case: "+case1name
          plot(0)   = gsn_csm_contour_map_polar(wks,eof1_regres(n,:,:),res)

          ;---Draw second plot in upper right corner
          res@gsnLeftString     = "Regression ("+eof(n)+")";(EOF "+(n+1)+")"
          res@gsnRightString    = sprintf("%5.1f", eof2@pcvar(n)) +"%"
          res@gsnCenterString   = "" ;case2name
          res@tiMainString      = "Case: "+case2name
          plot(1) = gsn_csm_contour_map_polar(wks,eof2_regres(n,:,:),res)

         ;res1=res
         ;res1@cnFillOn              = True     ; color plot desired
         ;res1@lbLabelBarOn          = False    ; turn off contour labels
         ;res1@cnLinesOn             = False    ; turn off contour lines
         ;res1@cnLineLabelsOn        = False    ; turn off contour labels
         ;res1@cnMissingValFillColor = -1
         ;res1@cnMonoFillColor       = True     ; default color is fground [black]
         ;res1@cnMonoFillPattern     = True     ; want multiple patterns
         ;res1@cnMonoFillScale       = True     ; want patterns w/ diff densities
         ;res1@cnFillColor           = FillColor
         ;res1@cnFillPattern         = FillPattern
         ;res1@cnFillScaleF          = FillScaleF
         ;res1@cnFillDotSizeF        = FillDotSizeF
         ;res1@cnFillOpacityF        = FillOpacityF
         ;res1@tiMainString          = "" ;label
         ;res1@cnInfoLabelOn         = False
         ;str1=unique_string("tmp1")
         ;str2=unique_string("tmp2")
         ;;wrf_smooth_2d(eof1_regres(n,:,:),3)
         ;;wrf_smooth_2d(eof2_regres(n,:,:),3)
         ;plot@str1                = gsn_csm_contour_map_polar(wks,eof1_prob(n,:,:),res1)
         ;plot@str2                = gsn_csm_contour_map_polar(wks,eof2_prob(n,:,:),res1)
         ;overlay(plot(0),plot@str1)
         ;overlay(plot(1),plot@str2)
         ;delete([/res1/])

          mkres = True
          mkres@gsMarkerIndex        = 16          ; Filled dots
          mkres@gsMarkerSizeF        = FillDotSizeF 
          mkres@gsMarkerColor        = FillColor
          mkres@gsMarkerOpacityF     = FillOpacityF
         ;mkres@gsMarkerThicknessF   = FillScaleF
          mkres@cnFillOpacityF       = FillOpacityF

          str1=unique_string("tmp1")
          str2=unique_string("tmp2")
         ;wrf_smooth_2d(eof1_regres(n,:,:),3)
         ;wrf_smooth_2d(eof2_regres(n,:,:),3)
          plot@str1                = gsn_add_polymarker(wks,plot(0),eof2_lon(n,:),eof2_lat(n,:),mkres)
          plot@str2                = gsn_add_polymarker(wks,plot(1),eof2_lon(n,:),eof2_lat(n,:),mkres)
      
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
          rts@gsnXYBarChart         = True            ; create bar chart 
          rts@gsnAboveYRefLineColor = "red"           ; above ref line fill red
          rts@gsnBelowYRefLineColor = "blue"          ; below ref line fill blue

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
          rts@gsnLeftString     = eof(n)+" index" ;(EOF "+(n+1)+")"
          rts@gsnRightString    = sprintf("%5.1f", eof1@pcvar(n)) +"%"
          rts@tiMainString      = "" ;"Case: "+case1name
          plot(2) = gsn_csm_xy (wks,yyyy1,eof1_ts(n,:),rts)
           
          rts1 = rts
          rts1@gsnXYBarChart       = False
          rts1@gsnLeftString       = ""
          rts1@gsnRightString      = ""
          rts1@gsnCenterString     = ""
          rts1@xyLineThicknesses   = 3            
          rts1@xyLineColors        = "Black"
          xyarr1                   = wgt_runave_Wrap(eof1_ts(n,:),(/1.,3,5,6,5,3,1/), 0)   
          tsmap1(2)            = gsn_csm_xy(wks,yyyy1,xyarr1,rts1) 
          overlay(plot(2),tsmap1(2))
          delete([/xyarr1/])


          ;---Draw fourth plot in upper right corner
          rts@gsnLeftString        = eof(n)+" index" ;(EOF "+(n+1)+")"
          rts@gsnRightString       = sprintf("%5.1f", eof2@pcvar(n)) +"%"
          rts@tiMainString         = "" ;"Case: "+case2name
          plot(3) = gsn_csm_xy (wks,yyyy2,eof2_ts(n,:),rts)

          rts2 = rts
          rts2@gsnXYBarChart       = False
          rts2@gsnLeftString       = ""
          rts2@gsnRightString      = ""
          rts2@gsnCenterString     = ""
          rts2@xyLineThicknesses   = 3 
          rts2@xyLineColors        = "Black"
          xyarr2                   = wgt_runave_Wrap(eof2_ts(n,:),(/1.,3,5,6,5,3,1/), 0) 
          tsmap2(3)            = gsn_csm_xy(wks,yyyy2,xyarr2,rts2)
          overlay(plot(3),tsmap2(3))
          delete([/xyarr2/])

       ; panel plot only resources
          pres1                          = True                ; mods desired
          pres1@gsnFrame                 = False               ; save panel until both ready
          pres1@gsnPanelBottom           = 0.45    ; space for label bar
          pres1@gsnPanelTop              = 0.85     ; only panel on lower half of page
          pres1@gsnPanelXF               = (/0.07,0.57/)
          gsn_panel(wks,plot(0:1),(/1,2/),pres1)          ; create first panel
          
          pres2                           = True                ; mods desired
          pres2@gsnFrame                  = False               ; save panel until both ready
          pres2@gsnPanelBottom            = 0.05                ; draw from center to right edge
          pres2@gsnPanelTop               = 0.5		       ; draw from center to right edge 
         ;gsn_panel(wks,plot(2:3),(/1,2/),pres2)       ; create first panel
 
          ;if (wtype .eq. "png") then
          ;   tmpa = systemfunc("convert "+fe+".png -trim del.png")
          ;   tmpb = systemfunc("mv del.png "+fe+".png")
          ;end if
      
          frame(wks)                                   ; draw both on same page

         ;delete([/xyarr1,xyarr2,tsmap1,tsmap2/])
         end do ; end of eof mods 
         delete([/regxAnom,regyAnom,regx1,regy1/])
         delete([/eof1_regres,eof2_regres,latx1,lonx1,latx2,lonx2/])
         delete([/yyyy1,yyyy2/])

         ;delete([/f1,ps1,ha1,hb1,p0,p1,f2,ps2,ha2,hb2,p2/])
          
        end do                                              ; end of looping over variables

        delete([/eof1,eof2/])

     end do                                                 ; end of looping over seasons

  end do                                                    ; end of looping over pressure levels


end

