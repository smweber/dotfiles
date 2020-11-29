# This is a sample commands.py.  You can add your own commands here.
#
# Please refer to commands_full.py for all the default commands and a complete
# documentation.  Do NOT add them all here, or you may end up with defunct
# commands when upgrading ranger.

# A simple command for demonstration purposes follows.
# -----------------------------------------------------------------------------

from __future__ import (absolute_import, division, print_function)

# You can import any python module as needed.
import os

# You always need to import ranger.api.commands here to get the Command class:
from ranger.api.commands import Command


# Any class that is a subclass of "Command" will be integrated into ranger as a
# command.  Try typing ":my_edit<ENTER>" in ranger!
class my_edit(Command):
    # The so-called doc-string of the class will be visible in the built-in
    # help that is accessible by typing "?c" inside ranger.
    """:my_edit <filename>

    A sample command for demonstration purposes that opens a file in an editor.
    """

    # The execute method is called when you run this command in ranger.
    def execute(self):
        # self.arg(1) is the first (space-separated) argument to the function.
        # This way you can write ":my_edit somefilename<ENTER>".
        if self.arg(1):
            # self.rest(1) contains self.arg(1) and everything that follows
            target_filename = self.rest(1)
        else:
            # self.fm is a ranger.core.filemanager.FileManager object and gives
            # you access to internals of ranger.
            # self.fm.thisfile is a ranger.container.file.File object and is a
            # reference to the currently selected file.
            target_filename = self.fm.thisfile.path

        # This is a generic function to print text in ranger.
        self.fm.notify("Let's edit the file " + target_filename + "!")

        # Using bad=True in fm.notify allows you to print error messages:
        if not os.path.exists(target_filename):
            self.fm.notify("The given file does not exist!", bad=True)
            return

        # This executes a function from ranger.core.acitons, a module with a
        # variety of subroutines that can help you construct commands.
        # Check out the source, or run "pydoc ranger.core.actions" for a list.
        self.fm.edit_file(target_filename)

    # The tab method is called when you press tab, and should return a list of
    # suggestions that the user will tab through.
    # tabnum is 1 for <TAB> and -1 for <S-TAB> by default
    def tab(self, tabnum):
        # This is a generic tab-completion function that iterates through the
        # content of the current directory.
        return self._tab_directory_content()

# Any class that is a subclass of "Command" will be integrated into ranger as a
# command.  Try typing ":my_edit<ENTER>" in ranger!
class new_note(Command):
    # The so-called doc-string of the class will be visible in the built-in
    # help that is accessible by typing "?c" inside ranger.
    """:new_note <note title>

    Create a new Markdown note with a date-prepended filename and the title prepopulated.
    """

    def execute(self):
        from os.path import join, expanduser, lexists
        from datetime import datetime
        import unicodedata, re

        # Build a fancy filename for our new note
        if self.arg(1):
            text = self.rest(1).strip()
            file_title = unicode(text)
            file_title = unicodedata.normalize('NFKD', file_title).encode('ascii', 'ignore').decode('ascii')
            file_title = re.sub(r'[^\w\s-]', '', file_title)
            note_title = text
        else:
            file_title = datetime.now().strftime("%H-%M-%S")
            note_title = datetime.now().strftime('%A, %B %d, %Y at %H:%M:%S')

        date_string = datetime.now().strftime("%Y-%m-%d")
        target_filename = str(date_string + " - " + file_title + ".md")

        fname = join(self.fm.thisdir.path, target_filename)

        if not lexists(fname):
            handle = open(fname, 'a')
            handle.write(note_title)
            handle.write("\n" + ("=" * len(note_title)))
            handle.write("\n(" + datetime.now().strftime('%A, %B %d, %Y at %I:%M %p') + ")")
            handle.write("\n")

            handle.close()
        else:
            self.fm.notify("file/directory exists!", bad=True)

        self.fm.reload_cwd()
        self.fm.edit_file(fname)
        self.fm.notify("FILENAME: " + fname)
        self.fm.select_file(fname)

    # The tab method is called when you press tab, and should return a list of
    # suggestions that the user will tab through.
    # tabnum is 1 for <TAB> and -1 for <S-TAB> by default
    def tab(self, tabnum):
        # This is a generic tab-completion function that iterates through the
        # content of the current directory.
        return self._tab_directory_content()

class notes(Command):
    # The so-called doc-string of the class will be visible in the built-in
    # help that is accessible by typing "?c" inside ranger.
    """:notes

    Open the notes directory
    """

    def execute(self):
        self.fm.cd("~/.notes")
        self.fm.thisdir.unload()
        self.fm.thisdir.flat = -1
        self.fm.thisdir.load_content()
