TEXBASE=moth_manuscript
BIBFILE=mothbib.bib
REBUTTALBASE=

TEXFILE=$(TEXBASE).tex
PDFFILE=$(TEXBASE).pdf
TXTFILE=$(TEXBASE).txt

PDFFIGURES=$(shell sed -n -e '/^[^%].*includegraphics/{s/^.*includegraphics.*{\([^}]*\)}.*/\1.pdf/;p}' $(TEXFILE))
# PDFFIGURES=$(filter-out toblerone_animated.pdf, $(ALLPDFFIGURES))

PT=$(wildcard *.py)
PYTHONFILES=$(filter-out plotstyle.py myfunctions.py numerical_compar_both.py, $(PT))
PYTHONPDFFILES=$(PYTHONFILES:.py=.pdf)

REVISION=9c0357fed0321f400c66878411d227f66e81c90b

ifdef REBUTTALBASE
REBUTTALTEXFILE=$(REBUTTALBASE).tex
REBUTTALPDFFILE=$(REBUTTALBASE).pdf
endif
REBUTTALREVISION=

# all ###########################################################
ifdef REBUTTALBASE
all: bib rebuttalbib
else
all: bib
endif

# python #########################################################
plots: $(PYTHONPDFFILES)
$(PYTHONPDFFILES): %.pdf: %.py plotstyle.py
	python3 $<

watchplots :
	while true; do ! make -q plots && make plots; sleep 0.5; done


# rescue_local_eod manuscript #################################################
bib: $(TEXBASE).bbl
$(TEXBASE).bbl: $(TEXFILE) $(BIBFILE)
	lualatex $(TEXFILE)
	biber $(TEXBASE)
	lualatex $(TEXFILE)
	lualatex $(TEXFILE)
	lualatex $(TEXFILE)
	@echo
	@echo "BibTeX log:"
	@sed -n -e '1,/You.ve used/p' $(TEXBASE).blg

pdf: $(PDFFILE)
$(PDFFILE) : $(TEXFILE)
	lualatex -interaction=scrollmode $< | tee /dev/stderr | fgrep -q "Rerun to get cross-references right" && lualatex -interaction=scrollmode $< || true

again :
	lualatex $(TEXFILE)

# watch files #######################################################
watchpdf :
	while true; do ! make -s -q pdf && make pdf; sleep 0.5; done


# make diffs ########################################################
diff :
	#latexdiff-git -r $(REVISION) --pdf $(TEXFILE)
	latexdiff-git -r $(REVISION) $(TEXFILE)
	-lualatex $(TEXBASE)-diff$(REVISION)
	-biber $(TEXBASE)-diff$(REVISION)
	-lualatex $(TEXBASE)-diff$(REVISION)
	-lualatex $(TEXBASE)-diff$(REVISION)
	-lualatex $(TEXBASE)-diff$(REVISION)
	mv $(TEXBASE)-diff$(REVISION).pdf $(TEXBASE)-diff.pdf
	mv $(TEXBASE)-diff$(REVISION).tex $(TEXBASE)-diff.tex
	mv $(TEXBASE)-diff$(REVISION).bbl $(TEXBASE)-diff.bbl
	rm $(TEXBASE)-diff$(REVISION).*


# convert to txt file ################################################
txt: $(PDFFILE)
	#dvi2tty -w 132 -v 500000 -e-60 -q $(DVIFILE) | sed -n -e '/\cL/,+2!p' > $(TXTFILE)
	pdftotext -nopgbrk $(PDFFILE) - | fold -s > $(TXTFILE)

# convert to rtf file ################################################
rtf :
	latex2rtf $(TEXFILE)

# remove all fancy commands from the tex file:
simplify :
	sed -e '/overall style/,/page style/d; /setdoublespacing/,+1d; /usepackage.*caption/s/{\(.*\)}/\1/; /figure placement/,/^%/d; /ifthenelse.*nofigs/,/#1/d; /begin{multicols}/d; /end{multicols}/d; /begin{keywords}/,/end{keywords}/d; /begin{contributions}/,/end{contributions}/d; /figurecaptions/d; /linenomath/d; s/captionc/caption/' $(TEXFILE) | perl -00 -lpe 's/\\showfigure{((\s|.)*?)}/$$1/' > $(TEXBASE)-simplified.tex

# statistics #########################################################
stats: $(PDFFILE)
# use \pagestyle{empty} and don't include any pictures!
	pdftotext -nopgbrk $(PDFFILE) - | fold -s > tmp.txt
	@echo
	@echo "     words: " `wc -w tmp.txt 2> /dev/null | cut -d ' ' -f 1` 
	@echo "characters: " `wc -c tmp.txt 2> /dev/null | cut -d ' '  -f 1`
	rm tmp.txt

# rebuttal ##########################################################
ifdef REBUTTALBASE
rebuttalbib: $(REBUTTALBASE).bbl
$(REBUTTALBASE).bbl: $(REBUTTALTEXFILE) $(BIBFILE)
	lualatex $(REBUTTALTEXFILE)
	bibtex $(REBUTTALBASE)
	lualatex $(REBUTTALTEXFILE)
	lualatex $(REBUTTALTEXFILE)
	lualatex $(REBUTTALTEXFILE)
	@echo
	@echo "BibTeX log:"
	@sed -n -e '1,/You.ve used/p' $(REBUTTALBASE).blg

rebuttal: $(REBUTTALPDFFILE)
$(REBUTTALPDFFILE) : $(REBUTTALTEXFILE)
	lualatex -interaction=scrollmode $< | tee /dev/stderr | fgrep -q "Rerun to get cross-references right" && lualatex -interaction=scrollmode $< || true

watchrebuttal :
	while true; do ! make -q rebuttal && make rebuttal; sleep 0.5; done

rebuttaldiff :
	latexdiff-git -r $(REBUTTALREVISION) --append-textcmd="response,issue" --pdf $(REBUTTALTEXFILE)
	mv $(REBUTTALBASE)-diff$(REBUTTALREVISION).pdf $(REBUTTALBASE)-diff.pdf
	rm $(REBUTTALBASE)-diff$(REBUTTALREVISION).*
endif

# git ##############################################################
pull :
	git pull origin master

ifdef REBUTTALBASE

edit : pull
	emacs $(TEXFILE) $(BIBFILE) $(REBUTTALTEXFILE) Makefile &
	sleep 1
	okular $(REBUTTALPDFFILE) $(PDFFILE) &

prepare : pull bib diffrev rebuttalbib rebuttaldiff

else

edit : pull
	emacs $(TEXFILE) $(BIBFILE) Makefile &
	sleep 1
	okular $(PDFFILE) &

prepare : pull bib diffrev

endif

push : prepare
	git commit -a
	git push origin master 

# convert figures to png files #######################################
figures:
	./latexfigures2png $(TEXFILE)

# convert pdf figures to eps #########################################
epsfigures:
	#for i in $(PDFFIGURES); do echo $$i; rm -f $${i%.pdf}.eps; pdftops -level3 -eps $$i $${i%.pdf}.eps; done
	for i in $(PDFFIGURES); do echo $$i; rm -f $${i%.pdf}.eps; gs -q -dNOCACHE -dNOPAUSE -dBATCH -dSAFER -sDEVICE=epswrite -sOutputFile=$${i%.pdf}.eps $$i; done

# clean up ############################################################

clean:
	rm -rf auto *~ *.aux *.blg *.bbl *.dvi *.log *.out *.fff *.ttt $(PDFFIGURES) __pycache__

cleanall: clean
	rm -f $(PDFFILE) figure-??.png

# help ################################################################
help : 
	@echo -e \
	"make pdf:           make the pdf file of the paper.\n"\
	"make bib:           run bibtex and make the pdf file of the paper.\n"\
	"make again:         run pdflatex and make the pdf file of the paper,\n"\
        "                   no matter whether you changed the .tex file or not.\n"\
	"make watchpdf:      make the pdf file of the paper\n"\
        "                   whenever the tex file is modified.\n"\
	"make diff:          make a diff file against the specified revision (REVISION variable)\n"\
	"make txt:           make a plain text version of the paper ($(TXTFILE)).\n"\
	"make rtf:           convert the paper ($(TXTFILE)) to rtf format.\n"\
	"make simplify:      strip all fancy commands from the paper ($(TXTFILE))\n"\
	"make stats:         print number of words and characters.\n"\
	"make rebuttalbib:   run bibtex and make the pdf file of the rebuttal.\n"\
	"make rebuttal:      make the pdf file of the rebuttal.\n"\
	"make watchrebuttal: make the pdf file of the rebuttal\n"\
        "                   whenever the tex file is modified.\n"\
	"make rebuttaldiff:  make a diff file of the rebuttal against the specified revision\n"\
        "                   (REBUTTALREVISION variable).\n"\
	"make pull:          pull from the git repository.\n"\
	"make edit:          pull and open emacs and okular with te relevant files.\n"\
	"make prepare:       pull and make the pdfs and diffs of the manuscript and the rebuttal.\n"\
	"make push:          prepare, commit, and push to the git repository.\n"\
	"make figures   :    convert all figures to png files.\n"\
	"make epsfigures:    convert all included pdf figures to eps files.\n"\
	"make clean:         remove all intermediate files,\n"\
        "                   just leave the source files and the final .pdf files.\n"\
	"make cleanup:       remove all intermediate files as well as\n"\
        "                   the final .pdf files.\n"\
