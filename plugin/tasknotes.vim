" tasknotes.vim - TaskNotes plugin commands
" Maintainer: emiller

if exists('g:loaded_tasknotes')
  finish
endif
let g:loaded_tasknotes = 1

" Main commands
command! TaskNotesBrowse lua require('tasknotes').browse_tasks()
command! TaskNotesNew lua require('tasknotes').new_task()
command! TaskNotesEdit lua require('tasknotes').edit_task()
command! TaskNotesRescan lua require('tasknotes').rescan()

" Time tracking commands
command! TaskNotesTimerToggle lua require('tasknotes').toggle_timer()
command! TaskNotesTimerStatus lua require('tasknotes').timer_status()
command! TaskNotesTimeEntries lua require('tasknotes').view_time_entries()

" Filter commands
command! TaskNotesByStatus lua require('tasknotes').browse_tasks({status = vim.fn.input('Status: ')})
command! TaskNotesByPriority lua require('tasknotes').browse_tasks({priority = vim.fn.input('Priority: ')})
command! TaskNotesByContext lua require('tasknotes').browse_tasks({context = vim.fn.input('Context: ')})

" Obsidian integration
command! -nargs=1 TaskNotesImportObsidian lua require('tasknotes').import_obsidian_settings(<f-args>)

" Telescope extension commands (if available)
command! -nargs=? TaskNotesTelescope lua require('telescope').extensions.tasknotes.tasks({filter = <q-args>})
