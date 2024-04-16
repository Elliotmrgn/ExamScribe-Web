from fitz import fitz
import re
import uuid
import time
from question_extraction import Chapter

# TODO: 


class PDF_Processing:
    def __init__(self, pdf):
        self.doc = fitz.open(stream = pdf)
        self.quiz_id = uuid.uuid4().hex
        self.creation_date = str(int(time.time()))
        self.title = self.doc.metadata.get("title")
        self.author = self.doc.metadata.get("author")
        self.chapters = []
        self.total_questions = 0
        self.question_bank = []
        
        
    def build_chapters(self):
        """ Builds a map of the chapters for extraction. 
            This helps simplify the question and answer extraction to reduce
            future checks for page spillover and false matches."""
            
        toc = self.doc.get_toc()  # gets table of contents
        match_answer_chapter_to_question_chapter = 0  # matches answer chapter to corresponding question chapter
        is_answer_section = False  # indicator if started answer chapters

        # Sets title if not present in metadata
        if not self.title:
            self.title = toc[0][1]
        
        for index, entry in enumerate(toc):
            # entry[0] = chapter depth, entry[1] = chapter title, entry[2] = starting page number
            chapter_title = entry[1]
            # subtract 1 from the starting page number to match the list index of pages
            start_page = entry[2] - 1
            # check the next chapter starting page and subtract 2 to get last page of the previous chapter

            end_page = toc[index + 1][2] - 2
            # Check if the chapter title indicates it will be a chapter with questions
            if not is_answer_section and chapter_title.startswith("Chapter "):
                # Create chapter object with info extracted
                chapter = self._extract_question_chapter_info(chapter_title, start_page, end_page)
                self.chapters.append(chapter)
            # Special case needed when answers chapters start the same as question chapters
            elif chapter_title.startswith("Appendix") or chapter_title.startswith("Answers to the "):
                is_answer_section = True
            # Check if the chapter title indicates it will be a chapter with answers
            elif chapter_title.startswith("Answers to Chapter ") or (is_answer_section and chapter_title.startswith("Chapter")):
                # Add answer data to chapter (end page needs to check start page of next chapter in case they overlap)
                self._extract_answer_info(self.chapters[match_answer_chapter_to_question_chapter], start_page, end_page + 1)
                match_answer_chapter_to_question_chapter += 1
                # Once last chapter gets its answer data, stop checking
                if len(self.chapters) == match_answer_chapter_to_question_chapter:
                    break
        # Returns list of chapter objects
        print("** Chapter map finished building")
        return
       
       
    def _extract_question_chapter_info(self, chapter_title, start_page, end_page):
        # Grab the chapter number from the chapter title

        chapter_num = int(chapter_title.split(" ")[1][0])
        # Validate the start page is where questions begin
        start_page = self._validate_chapter_start_page(start_page, end_page, False)
        # Validate the end page is where questions end
        end_page = self._validate_chapter_end_page(start_page, end_page, False)
        chapter_total_questions = self._find_total_questions(end_page)

        return Chapter(self.doc, chapter_num, chapter_title, start_page, end_page, chapter_total_questions)


    def _validate_chapter_start_page(self, start_page, end_page, is_answer_section):
        # Checks which page is the actual starting page
        while start_page <= end_page:
            
            # page_data = self._extract_page_data( start_page, is_answer_section)
            
            # If a match is found return the starting page
            if self._extract_page_data( start_page, is_answer_section):
                return start_page
            # Otherwise check next page
            start_page += 1


    def _validate_chapter_end_page(self, start_page, end_page, is_answers_section, total_questions=None):
        # Checks which page is the actual end page
        while start_page <= end_page:
            page_data = self._extract_page_data(end_page, is_answers_section)
            if page_data:
                # When validating answer end pages make sure the last question is found
                if is_answers_section:
                    page_data = [int(question_num.replace(' ', '')) for question_num in page_data]
                    if max(page_data) == total_questions:
                        return end_page
                else:
                    return end_page

            end_page -= 1


    def _find_total_questions(self, end_page):
        # Grabs the questions on the last page
        page_data = self._extract_page_data(end_page, False)
        # Makes a list of the question numbers
        question_numbers = [int(questions[0].replace(' ', '')) for questions in page_data]
        # Returns the highest question
        return max(question_numbers)
    
    
    def _extract_page_data(self, page_number, is_answer_section):
        # Extracts either questions from page or answer numbers
        page_text = self.doc[page_number].get_text()
        if page_text:
            if not is_answer_section:
                question_regex = r"^([\d|\s\d][\d' ']*)\.\s(.*(?:\r?\n(?![\s]*[A-Z]\.\s)[^\n]*|)*)(.*(?:\r?\n(?![\d|\s\d][\d' ']*\.\s)[^\n]*|)*)"
                page_questions = re.findall(question_regex, page_text, re.MULTILINE)
                return page_questions
            elif is_answer_section:
                answer_regex = r"^[\d|\s\d][\d' ']*(?=\.[\s]*[A-Z])"
                page_answers = re.findall(answer_regex, page_text, re.MULTILINE)
                return page_answers


    def _extract_answer_info(self, chapter, start_page, end_page):
        chapter.answer_start_page = self._validate_chapter_start_page(start_page, end_page, True)
        chapter.answer_end_page = self._validate_chapter_end_page(start_page, end_page, True, chapter.total_questions)
        
        
    def build_question_bank(self):
        for i, chapter in enumerate(self.chapters):
            chapter.build_chapter_question_bank()
            self.question_bank.append({chapter.title: chapter.chapter_question_bank})
            print(f"** CHAPTER {i} FINISHED EXTRACTING!! ")

    # Currently unused
    def get_total_questions(self):
        for chapter in self.chapters:
            self.total_questions += chapter.total_questions